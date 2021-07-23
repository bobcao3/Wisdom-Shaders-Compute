import numpy as np
import taichi as ti
import math
import matplotlib.pyplot as plt
import os

ti.init(arch=ti.gpu)

samples = 20000
batch = 800000

integratedSpecular = ti.Vector.field(4, dtype=ti.f32, shape=(samples)) # per sample (wo, metalic, alpha, reflectance)

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
def D(h, alpha):
    theta_h = getTheta(h)
    tan_theta_h = ti.tan(theta_h)
    return ti.exp(-(tan_theta_h * tan_theta_h) / (alpha * alpha)) / (math.pi * (alpha * alpha) * (getCosTheta(h) ** 4.0))

@ti.func
def F0(metalic):
    return ti.max(0.04, 1.0 - metalic)

@ti.func
def BSDF(wo, wi, metalic, alpha):
    h = (wo + wi).normalized()

    f0 = F0(metalic)
    F = f0 + ((1.0 - wi.dot(h)) ** 5) * (1.0 - f0)

    specular = 0.0

    if (getCosTheta(wo) > 0 and getCosTheta(wi) > 0):
        # specular = F * G(wo, wi, alpha) * D(h, alpha) / (4.0 * getCosTheta(wo) * getCosTheta(wi))
        specular = F * G(wo, wi, alpha) / (4.0 * wi.dot(h) * ti.max(getCosTheta(wo), getCosTheta(wi)))

    return specular

@ti.func
def getHemisphereSample():
    r0 = ti.min(1.0 - 1e-3, ti.max(1e-3, ti.random()))
    r1 = ti.min(1.0 - 1e-3, ti.max(1e-3, ti.random()))

    r = ti.sqrt(r0)
    theta = 2.0 * math.pi * r1
    
    ph = ti.Vector([r * ti.cos(theta), r * ti.sin(theta), ti.sqrt(1.0 - r0)])
    pdf = ti.sqrt(1.0 - r0) / math.pi

    return (ph, pdf)

@ti.kernel
def generate_sample_point():
    for i in integratedSpecular:
        integratedSpecular[i] = ti.Vector([
            ti.min(1.0 - 1e-3, ti.max(1e-3, ti.random())),
            ti.min(1.0 - 1e-3, ti.max(1e-3, ti.sqrt(ti.random()))),
            ti.min(1.0 - 1e-3, ti.max(1e-3, ti.pow(ti.random(), 2.0))),
            0.0])

@ti.kernel
def integrate():
    for i in integratedSpecular:
        for j in range(1000):
            ndotv = integratedSpecular[i][0]

            r = ti.sqrt(1.0 - ndotv * ndotv)
            wo = ti.Vector([r, 0.0, ndotv])

            metalic = integratedSpecular[i][1]
            alpha = integratedSpecular[i][2]

            wi, pdf = getHemisphereSample()

            specular = BSDF(wo, wi, metalic, alpha) # * getCosTheta(wi) / pdf => this should be 1

            integratedSpecular[i][3] += specular / batch

@ti.kernel
def average():
    for i in integratedSpecular:
        integratedSpecular[i][3] = ti.min(1.0, ti.max(0.0, integratedSpecular[i][3]))

generate_sample_point()

for i in range(0, batch, 1000):
    print(i)
    integrate()

average()

s = integratedSpecular.to_numpy()

print(s.shape)

np.savetxt("brdf.csv", s, delimiter=",")
