###################################################
## SparkR Basics I: From CSV to SparkR DataFrame ##
###################################################

## Sarah Armstrong, Urban Institute  
## June 23, 2016  
## Last Updated: August 15, 2016


## Objective: Become comfortable working with the SparkR DataFrame (DF) API; particularly, understand how to:

## * Read a .csv file into SparkR as a DF
## * Measure dimensions of a DF
## * Append a DF with additional rows
## * Rename columns of a DF
## * Print column names of a DF
## * Print a specified number of rows from a DF
## * Print the SparkR schema
## * Specify schema in `read.df` operation
## * Manually specify a schema
## * Change the data type of a column in a DF
## * Export a DF to AWS S3 as a folder of partitioned parquet files
## * Export a DF to AWS S3 as a folder of partitioned .csv files
## * Read a partitioned file from S3 into SparkR

## SparkR Operations Discussed: `read.df`, `nrow`, `ncol`, `dim`, `withColumnRenamed`, `columns`, `head`, `str`, `dtypes`, `schema`, `printSchema`, `cast`, `write.df`


## Initiate Spark session:

if (nchar(Sys.getenv("SPARK_HOME")) < 1) {
  Sys.setenv(SPARK_HOME = "/home/spark")
}
# Load the SparkR library
library(SparkR, lib.loc = c(file.path(Sys.getenv("SPARK_HOME"), "R", "lib")))
# Initiate a SparkR session
sparkR.session()


######################################
## (1) Load a csv file into SparkR: ##
######################################

## Use the operation `read.df` to load in quarterly Fannie Mae single-family loan performance data from the AWS S3 folder `"s3://sparkr-tutorials/"` as a Spark DataFrame (DF). Below, we load a single quarter (2000, Q1) into SparkR, and save it as the DF `perf`:

perf <- read.df("s3://sparkr-tutorials/Performance_2000Q1.txt", header = "false", delimiter = "|", source = "csv", inferSchema = "true", na.strings = "")

## In the `read.df` operation, we give specifications typically included when reading data into Stata and SAS, such as the delimiter character for .csv files. However, we also include SparkR-specific input including `inferSchema`, which Spark uses to interpet data types for each column in the DF. We discuss this in more detail later on in this tutorial. An additional detail is that `read.df` includes the `na.strings = ""` specification because we want `read.df` to read entries of empty strings in our .csv dataset as NA in the SparkR DF, i.e. we are telling read.df to read entries equal to `""` as `NA` in the DF. We will discuss how SparkR handles empty and null entries in further detail in a subsequent tutorial.

## Note: documentation for the quarterly loan performance data can be found at http://www.fanniemae.com/portal/funding-the-market/data/loan-performance-data.html.

## We can save the dimensions of the 'perf' DF through the following operations. Note that wrapping the computation with () forces SparkR/R to print the computed value:

(n1 <- nrow(perf))	# Save the number of rows in 'perf'
(m1 <- ncol(perf))	# Save the number of columns in 'perf'

## Update a DataFrame with new rows of data:

## Since we'll want to analyze loan performance data beyond 2000 Q1, we append the `perf` DF below with the data from subsequent quarters of the same single-family loan performance dataset. Here, we're only appending one subsequent quarter (2000 Q2) to the DF so that our analysis in these tutorials runs quickly, but the following code can be easily adapted by specifying the `a` and `b` values to reflect the quarters that we want to append to our DF. Note that the for-loop below also uses the `read.df` operation, specified here just as when we loaded the initial .csv file as a DF:

a <- 2
b <- 2

for(q in a:b){
  
  filename <- paste0("Performance_2000Q", q)
  filepath <- paste0("s3://sparkr-tutorials/", filename, ".txt")
  .perf <- read.df(filepath, header = "false", delimiter = "|", 
                   source = "csv", inferSchema = "true", na.strings = "")
  
  perf <- rbind(perf, .perf)
}

## The result of the for-loop is an appended `perf` DF that consists of the same columns as the initial `perf` DF that we read in from S3, but now with many appended rows. We can confirm this by taking the dimensions of the new DF:

(n2 <- nrow(perf))
(m2 <- ncol(perf))


#####################################
## (2) Rename DataFrame column(s): ##
#####################################

## The `select` operation performs a by column subset of an existing DF. The columns to be returned in the new DF are specified as a list of column name strings in the `select` operation. Here, we create a new DF called `perf_lim` that includes only the first 14 columns in the `perf` DF, i.e. the DF `perf_lim` is a subset of `perf`:

cols <- c("_C0","_C1","_C2","_C3","_C4","_C5","_C6","_C7","_C8","_C9","_C10","_C11","_C12","_C13")
perf_lim <- select(perf, col = cols)

## We will discuss subsetting DataFrames in further detail in the "Subsetting" tutorial. For now, we will use this subsetted DF to learn how to change column names of DataFrames.

## Using a for-loop and the SparkR operation `withColumnRenamed`, we rename the columns of `perf_lim`. The operation `withColumnRenamed` renames an existing column, or columns, in a DF and returns a new DF. By specifying the "new" DF name as `perf_lim`, however, we simply rename the columns of `perf_lim` (we could create an entirely separate DF with new column names by specifying a different DF name for `withColumnRenamed`):

old_colnames <- c("_C0","_C1","_C2","_C3","_C4","_C5","_C6","_C7","_C8","_C9","_C10","_C11","_C12","_C13")
new_colnames <- c("loan_id","period","servicer_name","new_int_rt","act_endg_upb","loan_age","mths_remng",
                  "aj_mths_remng","dt_matr","cd_msa","delq_sts","flag_mod","cd_zero_bal","dt_zero_bal")

for(i in 1:14){
  perf_lim <- withColumnRenamed(perf_lim, existingCol = old_colnames[i], newCol = new_colnames[i] )
}

## We can check the column names of `perf_lim` with the `columns` operation or with its alias `colnames`:

columns(perf_lim)

## Additionally, we can use the `head` operation to display the first n-many rows of `perf_lim` (here, we'll take the first five (5) rows of the DF):

head(perf_lim, num = 5)

## We can also use the `str` operation to return a compact visualization of the first several rows of a DF:

str(perf_lim)

############################################
## (3) Understanding data-types & schema: ##
############################################

## We can see in the output for the command `head(perf_lim, num = 5)` that we have what appears to be several different data types (dtypes) in our DF. There are three (3) different ways to explicitly view dtype in SparkR - the operations `dtypes`, `schema` and `printSchema`. As stated above, Spark relies on a "schema" to determine what dtype to assign to each column in a DF (which is easy to remember since the English schema comes from the Greek word for shape or plan!). We can print a visual representation of the schema for a DF with the operations `schema` and `printSchema` while the `dtypes` operation prints a list of DF column names and their corresponding dtypes:

dtypes(perf_lim)	# Prints a list of DF column names and corresponding dtypes
schema(perf_lim)	# Prints the schema of the DF
printSchema(perf_lim) # Prints the schema of the DF in a concise tree format

## Specifying schema in `read.df` operation & defining a custom schema:

## Remember that, when we read in our DF from the S3-hosted .csv file, we included the condition `inferSchema = "true"`. This is just one of three (3) ways to communicate to Spark how the dtypes of the DF columns should be assigned. By specifying `inferSchema = "true"` in `read.df`, we allow Spark to infer the dtype of each column in the DF. Conversely, we could specify our own schema and pass this into the load call, forcing Spark to adopt our dtype specifications for each column. Each of these approaches have their pros and cons, which determine when it is appropriate to prefer one over the other:

## * `inferSchema = "true"`: This approach minimizes programmer-driven error since we aren't required to make assertions about the dtypes of each column; however, it is comparatively computationally expensive

## * `customSchema`: While computationally more efficient, manually specifying a schema will lead to errors if incorrect dtypes are assigned to columns - if Spark is not able to interpret a column as the specified dtype, `read.df` will fill that column in the DF with NA

## Clearly, the situations in which these approaches would be helpful are starkly different. In the context of this tutorial, an efficient use of both approaches would be to use `inferSchema = "true"` when reading in `perf`. At this point, we could print the schema with `schema` or `printSchema`, note the dtype for each column (all 28 of them), and then write a `customSchema` with the corresponding specifications (or changed from the inferred schema as needed). We could then use this `customSchema` when appending the subsequent quarters to `perf`. While writing the customSchema may be tedious, including it in the appending for-loop would help that process to be much more efficient - this would be especially useful if we were appending, for example, 20 years worth of quarterly data together. The third way to communicate to Spark how to define dtypes is to not specify any schema, i.e. to not include `inferSchema` in `read.df`. Under this condition, every column in the DF is read in as a string dtype. Below is the an example of how we could specify a customSchema (here, however, we just use the same dtypes as interpreted for `inferSchema = "true"`):

customSchema <- structType(
 structField("loan_id", type = "long"),
 structField("period", type = "string"),
 structField("servicer_name", type = "string"),
 structField("new_int_rt", type = "double"),
 structField("act_endg_upb", type = "double"),
 structField("loan_age", type = "integer"),
 structField("mths_remng", type = "integer"),
 structField("aj_mths_remng", type = "integer")
 structField("dt_matr", type = "string")
 structField("cd_msa", type = "integer")
 structField("delq_sts", type = "string")
 structField("flag_mod", type = "string")
 structField("cd_zero_bal", type = "integer")
 structField("dt_zero_bal", type = "string")
)

## Finally, dtypes can be changed after the DF has been created, using the `cast` operation. However, it is clearly more efficient to properly specify dtypes when creating the DF. A quick example of using the `cast` operation is given below:

# We can see in the results from the previous printSchema output that `loan_id` is a `long` dtype, here we `cast` it
# as a `string` and then call `printSchema` on this new DF
perf_lim$loan_id <- cast(perf_lim$loan_id, dataType = "string")
printSchema(perf_lim)

# If we want our original `perf_lim` DF, we can simply recast `loan_id` as a `long` dtype
perf_lim$loan_id <- cast(perf_lim$loan_id, dataType = "long")
printSchema(perf_lim)


#######################################
## (4) Export DF as data file to S3: ##
#######################################

## Throughout this tutorial, we've built the Spark DataFrame `perf_lim` of quarterly loan performance data, which we'll use in several subsequent tutorials. In order to use this DF later on, we must first export it to a location that can handle large data sizes and in a data structure that works with the SparkR environment. We'll save this example data to an AWS S3 folder (`"sparkr-tutorials"`) from which we'll access other example datasets. Below, we save `perf_lim` as a collection of parquet type files into the folder `"hfpc_ex"` using the `write.df` operation:

write.df(perf_lim, path = "s3://sparkr-tutorials/hfpc_ex", source = "parquet", mode = "overwrite")

## When working with the DF `perf_lim` in the analysis above, we were really accessing data that was partitioned across our cluster. In order to export this partitioned data, we export each partition from its node (computer) and then collect them into the folder `"hfpc_ex"`. This "file" of indiviudal, partitioned files should be treated like an indiviudal file when organizing an S3 folder, i.e. __do not__ attempt to save other DataFrames or files to this file. SparkR saves the DF in this partitioned structure to accomodate massive data.

## Consider the conditions required for us to be able to save a DataFrame as a single .csv file: the given DF would need to be able to fit onto a single node of our cluster, i.e. it would need to be able to fit onto a single computer. Any data that would necessitate using SparkR in analysis will likely not fit onto a single computer. Note that we have specified `mode = "overwrite"`, indicating that existing data in this folder is expected to be overwritten by the contents of this DF (additional mode specifications include `"error"`, `"ignore"` and `"append"`).

## The partitioned nature of `"hfpc_ex"` does not affect our ability to load it back into SparkR and perform further analysis. Below, we use the `read.df` to read in the partitioned parquet file from S3 as the DF `dat`:

dat <- read.df("s3://sparkr-tutorials/hfpc_ex", header = "false", inferSchema = "true")

## Below, we confirm that the dimensions and column names of `dat` and `perf_lim` are equal. When comparing DFs, each with a large number of columns, the following if-else statement can be adapted to check equal dimensions and column names across DFs:

dim1 <- dim(perf_lim)
dim2 <- dim(dat)
if (dim1[1]!=dim2[1] | dim1[2]!=dim2[2]) {
  "Error: dimension values not equal; DataFrame did not export correctly"
} else {
  "Dimension values are equal"
}

## We can also save the DF as a folder of partitioned .csv files with syntax similar to that which we used to export the DF as partitioned parquet files. Note, however, that this does not retain the column names like saving as partitioned parquet files does. The `write.df` expression for exporting the DF as a folder of partitioned .csv files is given below:

write.df(perf_lim, path = "s3://sparkr-tutorials/hfpc_ex_csv", source = "csv", mode = "overwrite")

## We can read in the .csv files as a DF with the following expression:

dat2 <- read.df("s3://sparkr-tutorials/hfpc_ex_csv", source = "csv", inferSchema = "true")

## Note that the DF columns are now given generic names, but we can use the same for-loop from a previous section in this tutorial to rename the columns in our new DF:

colnames(dat2)

for(i in 1:14){
  dat2 <- withColumnRenamed(dat2, existingCol = old_colnames[i], newCol = new_colnames[i])
}

colnames(dat2)