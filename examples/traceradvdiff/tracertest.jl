include("../../src/fourierflows.jl")

using FourierFlows
import FourierFlows, FourierFlows.TracerAdvDiff

include("./tracerutils.jl")
       

nx, kap, Lx, Ly = 256, 1e-4, 2*pi, 1.0      # Domain
U, ep, k1       = 1.0, 0.6, 2*pi/Lx         # Specify barotropic flow

h(x)  = Ly*(1.0 - ep*sin(k1*x))             # Topography
hx(x) = -Ly*k1*ep*cos(k1*x)                 # Topographic x-gradient

ub(x, y, t) = U/h(x)                        # Barotropic x-velocity
wb(x, y, t) = y*ub(x, y, t)*hx(x)/h(x)      # Topography-following z-velocity

CFL, del, umax = 0.2, Lx/nx, U/(Ly*(1-ep))  # Time stepping parameters
dt, tfinal = CFL*del/umax, Ly*Lx / U        # Integration for one period
nsteps = ceil(Int, tfinal/dt)               # Number of steps
substeps = ceil(Int, 0.01*nsteps)           # 100 snapshots


println("dt: ", CFL*del/umax)




# Initial condition
xi, yi, dc = 0.0, -0.5*Ly, 0.005*Lx
ci(x, y) = exp( -((x-xi)^2+(y-yi)^2)/(2*dc^2) ) / (2*pi*dc^2)




# Initialize problem
g = FourierFlows.TwoDGrid(nx, Lx, nx, Ly+ep; y0=-Ly-ep)
prob = TracerProblem(g, kap, ub, wb, CFL*del/umax)
TracerAdvDiff.set_c!(prob, ci)
M0i = M0(prob.vars.c, g)
Cy2i = maximum(Cy2(prob.vars.c, g))




# Diagnostics
calc_xcen(prob)    = Cx1(prob.vars.c, prob.grid)
calc_ycen(prob)    = Cy1(prob.vars.c, prob.grid)
calc_ybar(prob)    = cy1(prob.vars.c, prob.grid)
calc_yvar(prob)    = cy2(prob.vars.c, prob.grid)
calc_maxyvar(prob) = maximum(cy2(prob.vars.c, prob.grid))

xcen    = ProblemDiagnostic(calc_xcen, substeps, prob)
ycen    = ProblemDiagnostic(calc_ycen, substeps, prob)
ybar    = ProblemDiagnostic(calc_ybar, substeps, prob)
yvar    = ProblemDiagnostic(calc_yvar, substeps, prob)
maxyvar = ProblemDiagnostic(calc_maxyvar, substeps, prob)

diags = [xcen, ycen, ybar, yvar, maxyvar]




# Plotting
mask = Array{Bool}(g.nx, g.ny)
for j=1:g.ny, i=1:g.nx
  mask[i, j] = g.y[j] < -h(g.x[i]) ? true : false
end



function makeplot(axs, prob)
  vs, pr, g = unpack(prob)
  cplot = NullableArray(vs.c, mask)

  M2flat = 2.0*M0i*kap*maxyvar.time + maximum(Cy2i)

  axes(axs[1])
  pcolormesh(g.X, g.Y, PyObject(cplot))
  xlabel("x"); ylabel("z")

  axes(axs[2])
  plot(vs.t, maxyvar.data; color="C0", linestyle="-")
  plot(vs.t, M2flat;       color="C1", linestyle="--")
  xlabel("t"); ylabel("Variance")

  pause(0.01)
  nothing
end

fig, axs = subplots(nrows=2)




# Integrate
while prob.t < tfinal

  stepforward!(prob; nsteps=substeps)
  TracerAdvDiff.updatevars!(prob)
  increment!(diags)

  @printf("step: %04d, x-center: %.2e, y-center: %.2e, max y-variance: %.2e\n", 
    prob.step, xcen.value, ycen.value, maximum(yvar.value))

  makeplot(axs, prob)
  savefig(sprintf("./plots/tracertest_%06d.png", prob.step), dpi=240)

end
