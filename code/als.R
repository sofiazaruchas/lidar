# load libraries
library(lidR)
library(terra)
library(sf)

#load point cloud
als_dir <- "C:/Users/Sofia Zaruchas/OneDrive/Desktop/EAGLE/lidar/exam/data/als"
ctg <- readLAScatalog(als_dir)

print(ctg)
plot(ctg)

#create output path
dir.create("data/als_normalized", showWarnings = FALSE)
opt_output_files(ctg) <- "data/als_normalized/{*}_norm"

#inspectation of single las tile
las <- readLAS(list.files(als_dir, pattern = "\\.laz$", full.names = TRUE)[1])
plot(las, color = "ScanAngleRank", axis = TRUE, legend = TRUE)
las_check(las)

#Normalization of data
ctg_norm <- normalize_height(ctg, algorithm = knnidw())

list.files("data/als_normalized")

ctg_norm2 <- readLAScatalog("data/als_normalized", filter = "-drop_z_above 60 -drop_z_below -5")

#calculation of metrics
metrics <- pixel_metrics(ctg_norm2, func = .stdmetrics_z, res = 10)

print(metrics)

#visualisation of metrics
plot(metrics, "zsd", col = height.colors(50))
plot(metrics, "zmean", col = height.colors(50))

#canopy height model
opt_output_files(ctg_norm2) <- ""
chm <- rasterize_canopy(
  ctg_norm2,
  res = 1,
  algorithm = pitfree(thresholds = c(0, 2, 5, 10, 15), max_edge = c(0, 1.5))
)


print(chm)
plot(chm, col = height.colors(50))

#smoothing of canopy height model
ker <- matrix(1, 3, 3)
chm_smooth <- terra::focal(chm, w = ker, fun = mean, na.rm = TRUE)

plot(chm_smooth, col = height.colors(50))

#save results
dir.create("results", showWarnings = FALSE)

writeRaster(chm, "results/chm_moehnesee.tif", overwrite = TRUE)
writeRaster(metrics, "results/aba_metrics_moehnesee.tif", overwrite = TRUE)
writeRaster(chm_smooth, "results/chm_smoothed_moehnesee.tif", overwrite = TRUE)
