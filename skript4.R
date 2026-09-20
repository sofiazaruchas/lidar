library(sf)
library(lidR)
library(terra)

#load combined raster
combined <- rast("results/combined_disturbance.tif")

#find coordinates for vizualisation in cloud compare
confirmed <- combined == 3
healthy   <- combined == 0

# find connected disturbance patches 
confirmed_patches <- patches(confirmed, directions = 8, zeroAsNA = TRUE)

patch_sizes <- freq(confirmed_patches)
largest_patch_id <- patch_sizes$value[which.max(patch_sizes$count)]

largest_patch <- confirmed_patches == largest_patch_id
largest_patch[largest_patch == 0] <- NA

healthy_neighbors <- focal(healthy, w = matrix(1, 3, 3), fun = sum, na.rm = TRUE)
edge_candidates <- largest_patch & (healthy_neighbors >= 2)
edge_candidates[edge_candidates == 0] <- NA

coords <- crds(edge_candidates, na.rm = TRUE)
nrow(coords)
head(coords)

edge_values <- extract(healthy_neighbors, coords)
coords_ranked <- cbind(coords, neighbors = edge_values[,1])
coords_ranked <- coords_ranked[order(-coords_ranked[,"neighbors"]),]

head(coords_ranked, 10)

best_x <- coords_ranked[1, "x"]
best_y <- coords_ranked[1, "y"]
cat("Chosen coordinate:", best_x, best_y, "\n")

#reprojection
pt <- st_sfc(st_point(c(best_x, best_y)), crs = 32632)
pt_als <- st_transform(pt, crs = 25832)
pt_coords <- st_coordinates(pt_als)
pt_coords

#clipping
ctg_norm2 <- readLAScatalog("data/als_normalized", filter = "-drop_z_above 60 -drop_z_below -5")

subset <- clip_rectangle(ctg_norm2,
                         xleft   = pt_coords[1,1] - 75,
                         ybottom = pt_coords[1,2] - 75,
                         xright  = pt_coords[1,1] + 75,
                         ytop    = pt_coords[1,2] + 75
)

writeLAS(subset, "results/showcase_disturbance_edge.laz")
