#load libraries
library(terra)

#load satelite data
ndvi_2017 <- rast("data/sentinel2/openEO_2017-01-01Z.tif")
ndvi_2020 <- rast("data/sentinel2/openEO_2020-01-01Z.tif")
ndvi_2024 <- rast("data/sentinel2/openEO_2024-01-01Z.tif")


print(ndvi_2017)
plot(ndvi_2017)

#load ALS data
chm <- rast("results/chm_moehnesee.tif")
print(chm)