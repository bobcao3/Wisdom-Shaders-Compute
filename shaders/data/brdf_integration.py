import numpy as np
import taichi as ti
import math
import matplotlib.pyplot as plt
import os

import torch
import torch.nn as nn
import torch.nn.functional as F
from torch.utils.data import TensorDataset, DataLoader

ti.init(arch=ti.gpu)

n = 256
samples = 8192

integratedSpecular = ti.field(float, (n, n, n)) # maps (wo, metalic, alpha)->reflectance
canvas = ti.field(float, (n * 3, n))

X = ti.field(float, (n * n * n, 3))
Y = ti.field(float, (n * n * n))

@ti.func
def getCosTheta(v):
    return v.z

@ti.func
def Lambda(theta, alpha):
    r = 0.0
    absTanTheta = ti.abs(ti.tan(theta))
    if absTanTheta != math.inf:
        a = 1.0 / (alpha * absTanTheta)
        if a < 1.6:
            r = (1.0 - 1.259 * a + 0.396 * a * a) / (3.535 * a + 2.181 * a * a)
    return r

@ti.func
def getTheta(v):
    return ti.acos(ti.min(ti.abs(v.z), 1.0 - 1e-5))

@ti.func
def G(v, l, alpha):
    return 1.0 / (1.0 + Lambda(getTheta(v), alpha) + Lambda(getTheta(l), alpha))

@ti.func
def D(v, alpha):
    theta_h = getTheta(v)
    tan_theta_h = ti.tan(theta_h)
    return ti.exp(-(tan_theta_h * tan_theta_h) / (alpha * alpha)) / (math.pi * (alpha * alpha) * (getCosTheta(v) ** 4))

@ti.func
def F0(metalic):
    return ti.max(0.04, 1.0 - metalic)

@ti.func
def BSDF(wo, wi, metalic, alpha):
    h = (wo + wi).normalized()

    f0 = F0(metalic)
    F = f0 + ((1.0 - ti.max(0, wo.dot(h))) ** 5) * (1.0 - f0)

    specular = F * G(wo, wi, alpha) * D(wo, alpha) / ti.max(1e-5, 4.0 * ti.max(0, getCosTheta(wo)))

    return specular

@ti.func
def getHemisphereSample():
    r0 = ti.min(1 - 1e-5, ti.max(1e-5, ti.random()))
    r1 = ti.min(1 - 1e-5, ti.max(1e-5, ti.random()))

    r = ti.sqrt(r0)
    theta = 2.0 * math.pi * r1
    
    ph = ti.Vector([r * ti.cos(theta), r * ti.sin(theta), ti.sqrt(1.0 - r0)])
    pdf = ti.sqrt(1.0 - r0) / math.pi

    return (ph, pdf)

@ti.kernel
def integrate():
    for i, j, k in integratedSpecular:
        ndotv = ti.max(1e-5, (i + ti.random()) / n)
        wo = ti.Vector([0, 0, ndotv])
        metalic = ti.max(1e-5, (j + ti.random()) / n)
        alpha = ti.max(1e-5, (k + ti.random()) / n)

        wi, pdf = getHemisphereSample()

        specular = BSDF(wo, wi, metalic, alpha) / pdf

        integratedSpecular[i, j, k] += specular

gui = ti.GUI("Integrated BSDF", res=(n * 3, n))

@ti.kernel
def display(s: float):
    for i, j in canvas:
        if i < n:
            canvas[i, j] = ti.min(1.0, integratedSpecular[i, int(0.0 * n), j] / s)
        elif i < n * 2:
            canvas[i, j] = ti.min(1.0, integratedSpecular[i - n, int(0.5 * n), j] / s)
        else:
            canvas[i, j] = ti.min(1.0, integratedSpecular[i - n * 2, n - 1, j] / s)

@ti.kernel
def dump():
    for i, j, k in integratedSpecular:
        x = i / n
        y = j / n
        z = k / n
        ind = i * n * n + j * n + k
        X[ind, 0] = x
        X[ind, 1] = y
        X[ind, 2] = z
        Y[ind] = ti.min(1.0, integratedSpecular[i, j, k])

for i in range(samples):
    integrate()
    if i % 100 == 9:
        display(i + 1)
        gui.set_image(canvas)
        gui.show()

dump()

s = integratedSpecular.to_numpy()

X = torch.Tensor(X.to_numpy())
Y = torch.Tensor(Y.to_numpy())

print(X)
print(X.shape)
print(Y)

dataset = TensorDataset(X, Y)
dataloader = DataLoader(dataset, batch_size=2048, shuffle=True)

class Net(nn.Module):
    def __init__(self):
        super(Net, self).__init__()
        b = torch.Tensor([-0.1688, 1.895, 0.9903, -4.853, 8.404, -5.069])
        d = torch.Tensor([0.6045, 1.699, -0.5228, -3.603, 1.404, 0.1939, 2.661])
        bias = torch.Tensor([50.0])

        self.b = nn.Parameter(b)
        self.d = nn.Parameter(d)
        self.bias = nn.Parameter(bias)

    def poly(self, f0, gloss, ndotv):
        x = gloss
        y = ndotv
    
        bias = torch.clamp(torch.min(self.b[0] * x + self.b[1] * x * x, self.b[2] + self.b[3] * y + self.b[4] * y * y + self.b[5] * y * y * y), 0.0, 1.0)
    
        delta = torch.clamp(self.d[0] + self.d[1] * x + self.d[2] * y + self.d[3] * x * x + self.d[4] * x * y + self.d[5] * y * y + self.d[6] * x * x * x, 0.0, 1.0)
        scale = delta - bias 

        bias *= torch.clamp(self.bias * f0, 0.0, 1.0)
        return f0 * scale + bias

    def forward(self, x):
        return self.poly(x[:,1], 1.0 - x[:,2], x[:,0])

learning_rate = 1e-2
model = Net()
loss_fn = nn.MSELoss()
optim = torch.optim.Adam(model.parameters(), lr=learning_rate)

size = len(dataloader.dataset)
for e in range(10):
    for batch, (batch_x, y) in enumerate(dataloader):
        pred = model(batch_x)
        loss = loss_fn(pred, y)

        if batch % 100 == 99:
            print(loss)

        optim.zero_grad()
        loss.backward()
        optim.step()

    with torch.no_grad():
        pred = model(X)
        loss = loss_fn(pred, Y)
        print("Epoch", e, "MSE=", loss)

for name, param in model.named_parameters():
    if param.requires_grad:
        print(name, param.data)