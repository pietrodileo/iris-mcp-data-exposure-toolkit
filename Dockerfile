FROM docker.iscinternal.com/docker-intersystems/intersystems/iris-community:2026.3.0AI.136.0

# Set environment variables for the InterSystems IRIS instance
ENV IRISUSERNAME=_SYSTEM IRISPASSWORD=SYS IRISNAMESPACE=MCP_EXAMPLE

# Set the PATH environment variable to include the InterSystems IRIS binaries and other common directories
ENV PATH=/usr/irissys/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:/home/irisowner/bin

# Set the working directory to /home/irisowner/dev
WORKDIR /home/irisowner/dev

# Copy the necessary files into the container and set ownership and permissions
COPY merge.cpf App.Installer.cls iris.script config_http.toml ./

# Set the ownership and permissions for the copied files
COPY --chown=irisowner:irisowner --chmod=0755 src ./src
COPY --chown=irisowner:irisowner data ./data

# Start the InterSystems IRIS instance, merge the configuration file, run the script, and stop the instance
RUN iris start IRIS && iris merge IRIS merge.cpf && iris session IRIS < iris.script && iris stop IRIS quietly

# Expose the necessary ports for the InterSystems IRIS instance
EXPOSE 1972 52773 8080
