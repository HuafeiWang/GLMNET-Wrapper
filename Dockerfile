# Base image
FROM r-base:latest

# Copy R script
COPY dockerRScript.R ./

# Set up work directory
WORKDIR ./

# Copy glmnet package and its dependencies
COPY iterators_1.0.8.tar ./
COPY foreach_1.4.3.tar ./
COPY glmnet_2.0-5.tar ./

# Install glmnet package and its dependencies 
RUN R CMD INSTALL iterators_1.0.8.tar
RUN R CMD INSTALL foreach_1.4.3.tar
RUN R CMD INSTALL glmnet_2.0-5.tar

# Execute the script
# ENTRYPOINT ["Rscript", "dockerRScript.R"]