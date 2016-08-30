This software package is a wrapper built around the [GLMNET library](https://web.stanford.edu/~hastie/glmnet/glmnet_alpha.html), which fits a generalized linear model via penalized maximum likelihood. The wrapper extends the GLMNET library specifically for bioinfomatics research, where input files conform to a specific format. A dockerized version of the software package can also be found on [Docker Hub](https://hub.docker.com). Docker allows the application to run independent of the host environment, as long as a [docker](https://www.docker.com) runtime has been installed on the local machine.

Input files
==================================================
The software requires the input files to conform to a specific format. Any deviation can trigger an error message from the GLMNET wrapper.
- Files are [comma-seperated values (csv)](https://en.wikipedia.org/wiki/Comma-separated_values) files.
- Two files are required for the software package - one feature file and one clinical data file in most bioinformatics cases.

The __feature file__, as the name suggests, contains features data. The first column is the feature names and each subsequent column contains data for each patient. The first row starting with keyword "Patient ID", uniquely labels each patient. The second row till the sixest row are reserved for feature file bookkeeping and should not contain any feature information - they will be ignored by the software package as it is assumed that the features start from the seventh row. If your feature file does not have those bookkeeping information, pad the second row through the sixest row with a proper number of commas.

The __clinical file__, on the other hand, contains output data. The clinical file has the same format as the feature file. The first column is the output names and each subsequent column contains data for each patient. The first row starting with keyword "Patient ID", uniquely labels each patient. No padding is necessary for the second row through the sixes row since the software will scan the file to find the output name of interest.

Samples are included in the InputFileSample folder.

How to get started with the plain script
=================================================
- Download ./Code/DockerRScript/Dockerization/dockerRScript.R
- `Rscript dockerRScript.R [mode] [feature file path] [clinical file path] (output name of interest) (cvfit file path) [output file path] (cross-validation seed)`
	- mode
		- `-t`: training mode
		- `-p`: prediction mode
	- feature file path: path to the file that contains the feature data
	- clinical file path: path to the file that contains the output data
	- output name of interest (__used only for training mode__): name of the attribute that is of interest to make predicitons on
	- cvfit file path (__used only for prediction mode__): path to the file that contains the comprehensive raw training model data
	- output file path: path to the folder where output model files will be generated
	- cross-validation seed (__used only for training mode__)
		- `-strue`: use a predefined seed
		- `-sfalse`: use a random seed
- Training mode example: `Rscript dockerRScript.R -t ./features.csv ./clinicaldata.csv 'EGFR mutation result' ./outputs -strue`
- Prediction mode example: `Rscript dockerRScript.R -p ./features.csv ./clinicaldata.csv ./outputs/cvfit.RData ./outputs`

How to get started with the docker application
=================================================
Running the docker application is almost the same as running the plain script. The additional step is to set up a mapping between the docker environment data volume to your local machine folder. These two folders will be essentially synced with each other.

- `docker run -v [local machine folder]:[docker machine folder] -t -i [docker application name] /bin/bash`
	- local machine folder: the folder name of the folder in your local machine that contains the feature file and clinical file
	- docker machine folder: the folder name of the folder in your docker environment that will be synced with the local machine folder
	- docker application name: the name of the docker application
	- `-t -i` and `/bin/bash` allow you to access and navigate through the docker machine
- Example: docker run -v /Users/user/Docker/test/:/tmp/ -t -i training /bin/bash
Once you are in the docker machine, calling the script to train or predict is the same as running the plain script. 

Output
=================================================
Output files will be generated into the folder specifed by the user.

In the training mode, the output files are __model.csv__, __cvfit.RData__ and __training_matrix.RData__. __model.csv__ contains all features names and their associated weights. __cvfit.RData__ contains the raw training model data used for prediction. __training_matrix.RData__ contains the populated training matrix and allows the user to apply different methods directly on the training matrix. 

In the prediction mode, the output file is __prediction.csv__. The file contains all patients names and their associated prediction outcomes.

Samples are included in the OutputFileSample folder.

Dockerize the application
=================================================
You can modify the dockerRScript.R file to suit your needs. If you want to dockerize your updated script, you can follow instructions listed below.

- Download the [GLMNET library](https://cran.r-project.org/web/packages/glmnet/index.html) and its dependencies - [foreach](https://cran.r-project.org/web/packages/foreach/index.html) and [iterators](https://cran.r-project.org/web/packages/iterators/index.html).
- Download any dependencies that are required by your modification.
- Pull the [r-base](https://hub.docker.com/_/r-base/) from the docker hub. It is the base image where you will build your application onto.
- Configure the dockerization process by listing the dockerization instructions in the Dockerfile.
	
~~~
# Specify base image
FROM r-base:latest

# Copy R script
COPY dockerRScript.R ./

# Set up work directory
WORKDIR ./

# Copy glmnet package and its dependencies
COPY iterators_1.0.8.tar ./
COPY foreach_1.4.3.tar ./
COPY glmnet_2.0-5.tar ./

# Copy any additional dependencies
# COPY *** ./

# Install glmnet package and its dependencies 
RUN R CMD INSTALL iterators_1.0.8.tar
RUN R CMD INSTALL foreach_1.4.3.tar
RUN R CMD INSTALL glmnet_2.0-5.tar

# Install any additional dependencies
# RUN R CMD INSTALL ***.tar
~~~

Details of writing Dockerfile can be found [here](https://docs.docker.com/engine/reference/builder/).
- `docker build -t training .` A docker image named 'training' will be built.
You have now successfully created your customized docker application.

Communication
=================================================
- If you __have a feature request__, please open an issue.
- If you __found a bug__, please open an issue.
- If you __have a general question__, please open an issue.
- If you __want to contribute__, please submit a pull request.



