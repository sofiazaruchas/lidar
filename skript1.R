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

ctg_norm2 <- readLAScatalog("data/als_normalized")


