# Convert text to a numeric value if possible, return -1 if not available
convert_text_to_integer <- function(text) {
	if (!is.na(as.numeric(text))) {
		return (as.numeric(text))
	} else {
		return (-1)
	}
}

# Process clinical data lines, check if target_output exists and set up an id - target_output map
process_clinical_data <- function(clinical_lines, target_output) {
	output_names <- c()
	# Collect output names
	for (i in 1 : length(clinical_lines)) {
		tokens <- unlist(strsplit(clinical_lines[i], ','))
		output_name <- tokens[1]
		output_names <- append(output_names, output_name)
	}
	# Check if the target_output exists in the clinical file
	if (!(target_output %in% output_names)) {
		stop(paste('GLMNET Wrapper Error: Invalid target output specified: ', target_output))
	}

	# Set up the patient_id - target_output map
	id_output_map <- list()
	id_index <- match('Patient ID', output_names)
	target_output_index <- match(target_output, output_names)
	id_tokens <- unlist(strsplit(clinical_lines[id_index], ','))
	output_tokens <- unlist(strsplit(clinical_lines[target_output_index], ','))
	for (i in 2 : length(output_tokens)) {
		i_output <- convert_text_to_integer(output_tokens[i])
		if (i_output != -1) {
			id_output_map[[id_tokens[i]]] = i_output
		}	
	}
	return (id_output_map)
}

# Construct the training matrix for glmnet training
get_training_matrix <- function(feature_lines, id_output_map) {
	feature_start_index <- 7 # <---------------------------------------- !!! Hard-coded starting row index!!!
	
	# Collect patients IDs
	patient_ids <- c()
	tokens <- unlist(strsplit(feature_lines[1], ','))
	for (i in 2 : length(tokens)) {
		patient_ids <- append(patient_ids, tokens[i])
	}
	print (paste('GLMNET Wrapper Log: Number of patients in feature file: ', length(patient_ids), sep = ''))
	# Collect feature names 
	feature_names <- c('Intercept')
	for (i in feature_start_index : length(feature_lines)) {
		tokens <- unlist(strsplit(feature_lines[i], ','))
		feature_names <- append(feature_names, tokens[1])
	}

	# Set up the training matrix
	available_patient_ids <- c()
	training_matrix_entries <- c()

	for (i in 1 : length(patient_ids)) {
		patient_id <- patient_ids[i]
		# Check if the patient id is available in the clinical data
		if (!is.null(id_output_map[[patient_id]])) {
			available_patient_ids <- append(available_patient_ids, patient_id)
			# Append features
			for (j in feature_start_index : length(feature_lines)) {
				tokens <- unlist(strsplit(feature_lines[j], ','))
				training_matrix_entries <- append(training_matrix_entries, as.numeric(tokens[i+1]))
			}
			# Append output
			training_matrix_entries <- append(training_matrix_entries, as.numeric(id_output_map[[patient_id]]))
		}
	}
	print(paste('GLMNET Wrapper Log: Number of availble patients for training: ', length(available_patient_ids), sep = ''))
	# Construct the training matrix from its entries
	training_matrix <- matrix(training_matrix_entries, nrow = length(available_patient_ids), ncol = length(feature_names), byrow = TRUE)
	return (list(training_matrix, feature_names))
}

# Construct the prediction matrix for glmnet prediction
get_prediction_matrix <- function(feature_lines, clinical_lines) {
	feature_start_index <- 7 # <----------------------------------------!!! Hard-coded starting row index!!!

	# Collect patients IDs
	patient_ids <- c()
	tokens <- unlist(strsplit(feature_lines[1], ','))
	for (i in 2 : length(tokens)) {
		patient_ids <- append(patient_ids, tokens[i])
	}
	print (paste('Number of patients in feature file: ', length(patient_ids), sep = ''))
	# Construct the prediction matrix
	prediction_matrix_entries <- c()
	for (i in feature_start_index : length(feature_lines)) {
		tokens <- unlist(strsplit(feature_lines[i], ','))
		for (j in 2 : length(tokens)) {
			prediction_matrix_entries <- append(prediction_matrix_entries, as.numeric(tokens[j]))
		}
	}
	prediction_matrix <- matrix(prediction_matrix_entries, nrow = length(patient_ids), byrow = FALSE)
	return (list(prediction_matrix, patient_ids))
}

print_non_zero_features <- function(model_matrix) {
	non_zero_features <- c()
	for (i in 2 : nrow(model_matrix)) {
		if (model_matrix[i, 2] != 0) {
			non_zero_features <- append(non_zero_features, model_matrix[i, 1])
		}
	}
	print ('GLMNET Wrapper Log: Non-Zero Features:')
	print (non_zero_features)
}

# GLMNET Wrappers ------------------------------------------------------------------------------------------
# Carry out glmnet training and output model coeffients to the specified lcoation
glm_training <- function(training_matrix, feature_names, output_path) {
	print ('GLMNET Wrapper Log: glmnet training...')
	# Import the glmnet package
	library(glmnet)
	x <- training_matrix[, 1 : ncol(training_matrix) - 1]
	y <- training_matrix[, ncol(training_matrix)]
	# Number of different outputs
	n_y <- length(unique(y)) 
	classification_family <- ''
	if (n_y == 2) {
		classification_family <- 'binomial'
		print ('GLMNET Wrapper Log: Binomial model is being used.')
	} else if (n_y > 2) {
		classification_family <- 'multinomial'
		print ('GLMNET Wrapper Log: Multinomial model is being used.')
	} else {
		stop('GLMNET Wrapper Error: Single output class detected.')
	}
	cvfit <- cv.glmnet(x, y, family = classification_family)
	plot(cvfit)
	coefs <- coef(cvfit, s = cvfit$lambda.min)
	# Output the model coefficients
	model_matrix_entries <- c()
	for (i in 1 : length(feature_names)) {
		# Append feature name
		model_matrix_entries <- append(model_matrix_entries, feature_names[i])
		# Append coeffcient for the feature
		model_matrix_entries <- append(model_matrix_entries, coefs[i])
	}
	model_matrix <- matrix(model_matrix_entries, nrow = length(feature_names), ncol = 2, byrow = TRUE)
	print_non_zero_features(model_matrix)
	# Output the model file
	dir.create(output_path)
	write.table(model_matrix, file = paste(output_path, '/model.csv', sep = ''), quote = FALSE, sep = ',', row.names = FALSE, col.names = FALSE)
	# Save the cvfit as RData
	save(cvfit, file = paste(output_path, '/cvfit.RData', sep = ''))
	# Save the training matrix as RData
	save(training_matrix, file = paste(output_path, '/training_matrix.RData', sep = ''))
	print('GLMNET Wrapper Log: glmnet training completed - model files generated!')
}

# Carry out glmnet prediction and output the patients with the predicted output
glm_prediction <- function(prediction_matrix, cvfit, patient_ids, output_path) {
	print ('GLMNET Wrapper Log: glmnet predicting...')
	# Import the glmnet package
	library(glmnet)
	y_predict <- predict(cvfit, newx = prediction_matrix, type = 'class', s = 'lambda.min')
	output_matrix_entries <- c()
	for (i in 1 : length(patient_ids)) {
		# Append patient id
		output_matrix_entries <- append(output_matrix_entries, patient_ids[i])
		# Append prediction result
		output_matrix_entries <- append(output_matrix_entries, y_predict[i])
	}
	output_matrix <- matrix(output_matrix_entries, nrow = length(patient_ids), ncol = 2, byrow = TRUE)
	# Output the output file
	dir.create(output_path)
	write.table(output_matrix, file = paste(output_path, '/prediction.csv', sep = ''), quote = FALSE, sep = ',', row.names = FALSE, col.names = FALSE)
	print ('GLMNET Wrapper Log: glmnet predicting completed - output file generated!')
}
# ------------------------------------------------------------------------------------------------------------

# Validate input arguments and initiate glmnet training / prediction
process_args <- function(args) {
	print ('GLMNET Wrapper Log: Validating input arguments.')
	# Check number of input arguments
	# The input should have 6 arguments training mode and 5 arguments for prediction mode
	if (length(args) != 5 && length(args) != 6) {
		stop('GLMNET Wrapper Error: Incorrect number of arguments.')
	}
	# Check if the flag is a valid flag and the input has the correct number of arguments
	# -t training mode
	flag <- args[1]
	if (flag == '-t' && length(args) == 6) {
		# Training mode
		# docker run -v <local disk absolute path to the folder that contains the feature and clinical data file>:/tmp/ -t -i training_5 /bin/bash
		# e.g. docker run -v /Users/huafei/Dockerization/test/:/tmp/ -t -i training_5 /bin/bash
		# Rscript dockerRScript.R -t /tmp/features.csv /tmp/clinicaldata.csv 'EGFR mutation result' /tmp/outputs
		print ('GLMNET Wrapper Log: Training mode specified.')
		# Open feature file
		feature_file_name <- args[2]
		feature_file <- file(feature_file_name, open = 'r')
		feature_lines <- readLines(feature_file)
		# Open clinical file
		clinical_file_name <- args[3]
		clinical_file <- file(clinical_file_name, open = 'r')
		clinical_lines <- readLines(clinical_file)
		# Check if target_output exists
		target_output <- args[4]
		id_output_map <- process_clinical_data(clinical_lines, target_output)
		# Process feature file and set up the training matrix
		training_matrix_feature_names_list <- get_training_matrix(feature_lines, id_output_map)
		training_matrix <- training_matrix_feature_names_list[[1]]
		feature_names <- training_matrix_feature_names_list[[2]]
		# Store output path
		output_path <- args[5]
		# Set the seed according to user preference
		seed_option <- args[6]
		if (seed_option != '-strue' && seed_option != '-sfalse') {
			stop('GLMNET Wrapper Error: Incorrect seed specified.')
		} else if (seed_option == '-strue') {
			set.seed(101)
		}
		# Close files and proceed to next steps
		close(feature_file)
		close(clinical_file)
		print ('GLMNET Wrapper Log: Arguments validated.')
		# Glmnet training
		glm_training(training_matrix, feature_names, output_path)
	
	} else if (flag == '-p' && length(args) == 5) {
		# -p prediction mode
		# Rscript predict.R -p /tmp/features.csv /tmp/clinicaldata.csv /tmp/cvfit.RData /tmp/outputs
		print ('GLMNET Wrapper Log: Starting prediction session.')
		# Open feature file
		feature_file_name <- args[2]
		feature_file <- file(feature_file_name, open = 'r')
		feature_lines <- readLines(feature_file)
		# Open clinical file
		clinical_file_name <- args[3]
		clinical_file <- file(clinical_file_name, open = 'r')
		clinical_lines <- readLines(clinical_file)
		# Construct the prediction matrix
		prediction_matrix_patient_ids_list <- get_prediction_matrix(feature_lines, clinical_lines)
		prediction_matrix <- prediction_matrix_patient_ids_list[[1]]
		patient_ids <- prediction_matrix_patient_ids_list[[2]]
		# Load cvfit
		load(args[4])
		# Store output path
		output_path <- args[5]

		close(feature_file)
		close(clinical_file)
		print ('GLMNET Wrapper Log: Arguments validated.')
		# Glmnet prediction
		glm_prediction(prediction_matrix, cvfit, patient_ids, output_path)
	} else {
		stop('GLMNET Wrapper Error: Incorrect flag specified.')
	}
}

# Main function for taking command-line input and initiating training / prediction process
main <- function() {
	args <- commandArgs(trailingOnly = TRUE)
	# Process arguments and start training / predcition
	process_args(args)
}

main()
