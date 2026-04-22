FROM ubuntu:noble

ARG SUDO_PASSWORD
ARG USER_PASSWORD
ARG USER=moin
ARG UID=1000
ARG GID=1000

# set TZ
ENV TZ=Etc/UTC

# set sudo password
RUN echo "root:${SUDO_PASSWORD}" | chpasswd

# install linux packages
RUN apt update -qq
RUN apt-get install -y --no-install-recommends \
  curl sudo dumb-init ca-certificates \
  software-properties-common dirmngr \
  libpq-dev libssl-dev
RUN rm -rf /var/lib/apt/lists/*

# install R
RUN curl -fsSL https://cloud.r-project.org/bin/linux/ubuntu/marutter_pubkey.asc | tee -a /etc/apt/trusted.gpg.d/cran_ubuntu_key.asc
RUN add-apt-repository "deb https://cloud.r-project.org/bin/linux/ubuntu $(lsb_release -cs)-cran40/"
RUN apt-get install -y --no-install-recommends build-essential libcurl4-openssl-dev libssl-dev libxml2-dev r-base

# install R packages
RUN R -q -e 'install.packages("languageserver", repos="https://cloud.r-project.org")'
RUN R -q -e 'install.packages("DBI", repos="https://cloud.r-project.org")'
RUN R -q -e 'install.packages("RPostgres", repos="https://cloud.r-project.org")'
RUN R -q -e 'install.packages("jsonlite", repos="https://cloud.r-project.org")'
RUN R -q -e 'install.packages("data.table", repos="https://cloud.r-project.org")'
RUN R -q -e 'install.packages("readxl", repos="https://cloud.r-project.org")'
RUN R -q -e 'install.packages("tableone", repos="https://cloud.r-project.org")'
RUN R -q -e 'install.packages("ggplot2", repos="https://cloud.r-project.org")'
RUN R -q -e 'install.packages("writexl", repos="https://cloud.r-project.org")'
RUN R -q -e 'install.packages("sandwich", repos="https://cloud.r-project.org")'
RUN R -q -e 'install.packages("lmtest", repos="https://cloud.r-project.org")'

# install VS Code and extensions
RUN curl -fsSL https://code-server.dev/install.sh | sh

# create a non-root user
RUN useradd -m -s /bin/bash $USER
RUN echo "$USER ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/$USER
RUN chmod 0440 /etc/sudoers.d/$USER

# prepare workspace and ownership
RUN mkdir -p /home/$USER/project
RUN chown -R $USER:$USER /home/$USER

# switch to the non-root user
USER $USER
ENV HOME=/home/$USER
WORKDIR /home/$USER/project

COPY ./examples /home/$USER/project/examples
COPY ./workspace /home/$USER/project/

RUN code-server --install-extension reditorsupport.r

# pre-configure code-server user settings
RUN mkdir -p /home/$USER/.local/share/code-server/User
COPY --chown=$USER:$USER ./workspace/.vscode/settings.json /home/$USER/.local/share/code-server/User/settings.json

# Start code-server as the non-root user
EXPOSE 8080
ENTRYPOINT ["dumb-init", "code-server"]
CMD ["--bind-addr", "0.0.0.0:8080", "--auth", "none", "--disable-telemetry", "--disable-getting-started-override", ".", "WILLKOMMEN.md"]
