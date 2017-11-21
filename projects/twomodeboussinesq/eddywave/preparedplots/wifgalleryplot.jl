include("./plottools.jl")

using PyPlot, PyCall

import SLSPlotTools, FourierFlows.TwoModeBoussinesq

import FourierFlows.TwoModeBoussinesq: mode0apv, mode1apv, mode1speed, mode1w, 
  wave_induced_speed, wave_induced_psi, wave_induced_uv, lagrangian_mean_uv,
  calc_chi, calc_chi_uv, totalenergy, mode0energy, mode1energy, CFL,
  lagrangian_mean_psi, apv_induced_psi

@pyimport mpl_toolkits.axes_grid1 as pltgrid




# Names
names = [
 "gallery_nu1e+32_101f_n512_ep10_Ro10_nkw02.jld2",
 "gallery_nu1e+32_122f_n512_ep10_Ro10_nkw16.jld2",
 "gallery_nu1e+32_200f_n512_ep10_Ro10_nkw16.jld2",
]




# Plot parameters
eddylim = 10
    Ro0 = 0.04
    w0  = 1.00
  istep = 6

plotprefix = "./plots/wifgallery"

probs = []
ws = []
Chis = []
chispeeds = []
maxchispeed = 0.0

for (i, name) in enumerate(names)

  filename = "../data/$name"
  prob, steps = SLSPlotTools.load_boussinesq_ivp(filename)

  # Non-retrievable parameters
  nkw = 16
   kw = 2π*nkw/prob.grid.Lx
    α = (prob.params.N*kw)^2/(prob.params.f*prob.params.m)^2
    σ = prob.params.f*sqrt(1+α)
   tσ = 2π/σ
   Re = prob.grid.Lx/20

  # Get snapshot
  step = steps[istep]
  t, Zh, solc = SLSPlotTools.get_snapshot(filename, step)

  # Analysis
  Z = irfft(Zh, prob.grid.nx) 
  u = ifft(solc[:, :, 1])
  v = ifft(solc[:, :, 2])
  p = ifft(solc[:, :, 3])

  TwoModeBoussinesq.set_Z!(prob, Z)
  TwoModeBoussinesq.set_uvp!(prob, u, v, p)

  # Diagnostics
  w = mode1w(prob)
  w = w / maximum(abs.(w))

  Q = mode0apv(prob)
  PsiQ = apv_induced_psi(prob)

  Chi = calc_chi(prob)
  uc, vc = calc_chi_uv(prob)
  chispeed = sqrt.(uc.^2.0+vc.^2.0)

  push!(probs, prob)
  push!(ws, w)
  push!(Chis, Chi)
  push!(chispeeds, chispeed)

  maxchispeed = maximum([maximum(chispeed), maxchispeed])
end




# Make plot
close("all")
fig, axs = subplots(ncols=3, nrows=2, sharey=true, sharex=true, 
  figsize=(12, 8))

# Non-retrievable parameters
 prob = probs[1]
  nkw = 16
   kw = 2π*nkw/prob.grid.Lx
    α = (prob.params.N*kw)^2/(prob.params.f*prob.params.m)^2
    σ = prob.params.f*sqrt(1+α)
   tσ = 2π/σ
   Re = prob.grid.Lx/20
 x, y = prob.grid.X/Re, prob.grid.Y/Re
  sp0 = maxchispeed

for (i, prob) in enumerate(probs)
  
  axes(axs[1, i])
  axis("equal")
  pcolormesh(x, y, chispeeds[i], cmap="YlGnBu_r", vmin=0.0, vmax=sp0)
  contour(x, y, Chis[i], 10, colors="w", linewidths=0.5, alpha=0.3)

  axes(axs[2, i])
  axis("equal")
  pcolormesh(x, y, ws[i], cmap="RdBu_r", vmin=-w0, vmax=w0)
  
end

for ax in axs
  ax[:set_adjustable]("box-forced")
  ax[:set_xlim](-eddylim, eddylim)
  ax[:set_ylim](-eddylim, eddylim)
  ax[:tick_params](axis="both", which="both", length=0)
  ax[:axis]("off")
end

tight_layout(rect=(0.05, 0.05, 0.95, 0.95), h_pad=0.05, w_pad=0.01)
savefig("wifgallery.png", dpi=240)