library(testthat)
library(SpeciesPoolR)
library(openxlsx)

# Create a temporary CSV and XLSX file for testing
test_csv <- tempfile(fileext = ".csv")
test_xlsx <- tempfile(fileext = ".xlsx")
unsupported_file <- tempfile(fileext = ".txt")
writeLines("Some text data", con = unsupported_file)

# Sample data for testing
sample_data <- data.frame(
  Species = paste0("Species_", 1:200),
  Kingdom = rep(c("Plantae", "Animalia"), each = 100),
  Class = rep(c("Magnoliopsida", "Liliopsida", "Aves", "Mammalia"), each = 50)
)

# Write sample data to the CSV and XLSX files
write.csv(sample_data, test_csv, row.names = FALSE)
openxlsx::write.xlsx(sample_data, test_xlsx, rowNames = FALSE)

# Test: Reading CSV without filtering
test_that("get_data reads a CSV file without filtering", {
  data <- get_data(test_csv)
  expect_equal(nrow(data), 200)
  expect_equal(ncol(data), 3)
  expect_true("Species" %in% colnames(data))
})

# Test: Reading XLSX without filtering
test_that("get_data reads an XLSX file without filtering", {
  data <- get_data(test_xlsx)
  expect_equal(nrow(data), 200)
  expect_equal(ncol(data), 3)
  expect_true("Species" %in% colnames(data))
})

# Test: Filtering the data
test_that("get_data correctly filters data based on the provided expression", {
  filtered_data <- get_data(
    test_csv,
    filter = quote(
      Kingdom == "Plantae" &
        Class == "Magnoliopsida"
    )
  )
  expect_equal(nrow(filtered_data), 50)  # Expecting 110 rows after filtering
  expect_equal(ncol(filtered_data), 3)
  expect_true(all(filtered_data$Kingdom == "Plantae"))
  expect_true(all(filtered_data$Class == "Magnoliopsida"))
})

# Test: Unsupported file type
test_that("get_data throws an error for unsupported file types", {
  expect_error(get_data(unsupported_file))
})

# Clean up temporary files
unlink(test_csv)
unlink(test_xlsx)
unlink(unsupported_file)
