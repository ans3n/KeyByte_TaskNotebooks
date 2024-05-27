#Dockerfile, image, container
# Use Python 3.9 Slim Image as Base 
FROM python:3.9-slim

# Set the working directory
WORKDIR /app

# Copy the current directory contents into the container at /app
COPY . /app
# Add templatizer.py into the container
#ADD templatizer.py /app/templatizer.py

# Set the working directory
#WORKDIR /app

# Add the tiramisu-sample.tar.gz into the container
ADD clustering-results /app

#alternatively use a dot simply adds to the base folder in the container
# ADD templatizer.py .
# ADD tiramisu-sample.tar.gz .

# Install Dependencies
RUN pip install numpy scipy scikit-learn sortedcontainers statsmodels matplotlib torch

# Execute Command on Container Start
ENTRYPOINT ["python3", "./workload-simulator.py"]
