#load libraries
library(terra)
library(osmdata)
library(sf)


#load satelite data
ndvi_2017 <- rast("data/sentinel2/openEO_2017-01-01Z.tif")
ndvi_2020 <- rast("data/sentinel2/openEO_2020-01-01Z.tif")
ndvi_2024 <- rast("data/sentinel2/openEO_2024-01-01Z.tif")


print(ndvi_2017)
plot(ndvi_2017)

#load ALS data
chm_smooth <- rast("results/chm_smoothed_moehnesee.tif")
print(chm_smooth)

#align data
chm_aligned <- terra::project(chm_smooth, ndvi_2017, method = "average")
print(chm_aligned)

#calculate ndvi difference
ndvi_diff <- ndvi_2024 - ndvi_2017

#landcover mask
bbox <- c(8.13641, 51.45699, 8.19350, 51.48438)

water <- opq(bbox = bbox) |>
  add_osm_feature(key = "natural", value = "water") |>
  osmdata_sf()

settlement <- opq(bbox = bbox) |>
  add_osm_feature(key = "landuse", value = c("residential", "commercial", "industrial")) |>
  osmdata_sf()


exclude_sf <- c(
  st_geometry(water$osm_polygons),
  st_geometry(settlement$osm_polygons)
) |> st_transform(crs(ndvi_diff))

exclude_vect <- vect(exclude_sf)


ndvi_diff <- mask(ndvi_diff, exclude_vect, inverse = TRUE)


#plot ndvi difference
breaks <- matrix(c(
  -Inf, -0.3, 1,
  -0.3, -0.1, 2,
  -0.1,  0.1, 3,
  0.1,  0.3, 4,
  0.3,  Inf, 5
), ncol = 3, byrow = TRUE)

ndvi_class <- classify(ndvi_diff, rcl = breaks, include.lowest = TRUE)

levels(ndvi_class) <- data.frame(
  id = 1:5,
  category = c("Strong NDVI loss", "Slight NDVI loss", "Stable", "Slight NDVI gain", "Strong NDVI gain")
)

plot(ndvi_class,
     col = c("darkviolet", "violet", "khaki", "lightgreen", "darkgreen"),
     main = "NDVI Change 2017-2024")

levels(ndvi_class) <- data.frame(
  id = 1:5,
  category = c("Strong loss", "Slight loss", "Stable", "Slight gain", "Strong gain")
)

dir.create("results", showWarnings = FALSE)
dev.off()
png("results/ndvi_change_map.png", width = 1400, height = 1000, res = 150)
plot(ndvi_class,
     col = c("darkviolet", "violet", "khaki", "lightgreen", "darkgreen"),
     main = "NDVI Change 2017-2024")
dev.off()

#validate NDVI disturbance signal with CHM
ndvi_disturbed <- ndvi_diff < -0.2
chm_low <- chm_aligned < 5

combined <- ndvi_disturbed * 1 + chm_low * 2

levels(combined) <- data.frame(
  id = 0:3,
  category = c("Healthy forest", "NDVI only (uncertain)", "CHM only (uncertain)", "Confirmed disturbance")
)

png("results/validated_disturbance_map.png", width = 1800, height = 1000, res = 150)
plot(combined,
     col = c("#2c7bb6", "#abd9e9", "#fdae61", "#d7191c"),
     main = "Validated Disturbance Map (NDVI + CHM)",
     plg = list(cex = 0.8))
dev.off()

#saving
writeRaster(combined, "results/combined_disturbance.tif", overwrite = TRUE)

#sensitivity analysis
total_valid <- sum(!is.na(values(ndvi_diff)))


ndvi_thresholds <- c(-0.10, -0.15, -0.20, -0.25, -0.30)

ndvi_sensitivity <- sapply(ndvi_thresholds, function(t) {
  ndvi_dist <- ndvi_diff < t
  chm_dist  <- chm_aligned < 5
  confirmed <- ndvi_dist & chm_dist
  100 * sum(values(confirmed), na.rm = TRUE) / total_valid
})

ndvi_sensitivity_table <- data.frame(ndvi_threshold = ndvi_thresholds, percent_confirmed = ndvi_sensitivity)
print(ndvi_sensitivity_table)


chm_thresholds <- c(2, 3, 5, 7, 10)

chm_sensitivity <- sapply(chm_thresholds, function(t) {
  ndvi_dist <- ndvi_diff < -0.2
  chm_dist  <- chm_aligned < t
  confirmed <- ndvi_dist & chm_dist
  100 * sum(values(confirmed), na.rm = TRUE) / total_valid
})

chm_sensitivity_table <- data.frame(chm_threshold = chm_thresholds, percent_confirmed = chm_sensitivity)
print(chm_sensitivity_table)


y_range <- range(c(ndvi_sensitivity_table$percent_confirmed, chm_sensitivity_table$percent_confirmed))

png("results/sensitivity_analysis.png", width = 1600, height = 800, res = 150)
par(mfrow = c(1, 2))
plot(ndvi_sensitivity_table$ndvi_threshold, ndvi_sensitivity_table$percent_confirmed,
     type = "b", pch = 19, col = "darkred",
     xlab = "NDVI difference threshold", ylab = "% confirmed disturbance",
     main = "Sensitivity to NDVI threshold",
     ylim = y_range)
plot(chm_sensitivity_table$chm_threshold, chm_sensitivity_table$percent_confirmed,
     type = "b", pch = 19, col = "darkblue",
     xlab = "CHM height threshold (m)", ylab = "% confirmed disturbance",
     main = "Sensitivity to CHM threshold",
     ylim = y_range)
dev.off()

#calculate area statistics for each disturbance category
freq_table <- freq(combined)
print(freq_table)

write.csv(freq_table, "results/disturbance_area_statistics.csv", row.names = FALSE)

# convert pixel counts to hectares 
freq_table$hectares <- freq_table$count * 0.01
freq_table$percent <- 100 * freq_table$count / sum(freq_table$count)

print(freq_table)

write.csv(freq_table, "results/disturbance_area_statistics.csv", row.names = FALSE)

