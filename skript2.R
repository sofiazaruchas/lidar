#load libraries
library(openeo)

#connection to copernicus data space ecosystem
con <- connect(host = "https://openeo.dataspace.copernicus.eu")
login(con)

#create process builder
p <- processes(con)

#load datacube
datacube <- p$load_collection(
  id = "SENTINEL2_L2A",
  spatial_extent = list(west = 8.13641, east = 8.19350, south = 51.45699, north = 51.48438),
  temporal_extent = c("2017-01-01", "2024-12-31"),
  bands = list("B04", "B08"),
  properties = list("eo:cloud_cover" = function(x) p$lte(x, 50))
)

#Limit values to a valid range
datacube <- p$apply(data = datacube, process = function(x, context) {
  p$clip(x, min = 0, max = 10000)
})

#NDVI calculation
ndvi_function <- function(data, context) {
  red <- p$array_element(data = data, index = 0)
  nir <- p$array_element(data = data, index = 1)
  (nir - red) / (nir + red)
}

datacube_ndvi <- p$reduce_dimension(data = datacube, dimension = "bands", reducer = ndvi_function)

#time aggregation
datacube_yearly <- p$aggregate_temporal_period(
  data = datacube_ndvi,
  period = "year",
  reducer = function(data, context) {
    p$median(data)
  }
)

#create result and job
result <- p$save_result(data = datacube_yearly, format = "GTiff")
job <- create_job(con = con, graph = result, title = "NDVI_moehnesee_yearly")
start_job(con, job = job)
job_info <- describe_job(con, job = "j-2609100831134701b43fc0d706bce1a3")
as(job_info, "Process")

#save results
dir.create("data/sentinel2", showWarnings = FALSE)
download_results(con, job = "j-2609100831134701b43fc0d706bce1a3", folder = "data/sentinel2")

