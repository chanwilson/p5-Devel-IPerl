# Build:
#     docker build -t iperl .
# Run:
#     docker run --rm -p 8888:8888 -e JUPYTER_ENABLE_LAB=yes -v $(pwd):/home/jovyan/work iperl
#
# See also:
#   - <https://github.com/jupyter/docker-stacks>
ARG BASE_CONTAINER=jupyter/minimal-notebook

FROM $BASE_CONTAINER

ENV BUILD_DEPS=

USER root

RUN apt-get update \
	&& DEBIAN_FRONTEND=noninteractive apt-get install -yq --no-install-recommends \
		libzmq3-dev cpanminus curl \
		build-essential libx11-dev libgd-dev libhdf4-alt-dev libproj-dev proj-bin libcfitsio-dev libreadline-dev pgplot5 libvpx-dev libxpm-dev libxi-dev libxmu-dev freeglut3-dev libgsl0-dev libnetpbm10-dev  libssl-dev mysql-client mysql-common libmysqlclient-dev \
	&& cpanm -n App::cpm && rm -fR /home/jovyan/.cpanm

# set perl environment variables
ENV PERL_PATH=/home/jovyan/perl5
ENV PERL5LIB=$PERL_PATH:$PERL_PATH/lib/perl5:$PERL5LIB
ENV PERL_MM_OPT="INSTALL_BASE=$PERL_PATH"
ENV PERL_MB_OPT="--install_base $PERL_PATH"
ENV PATH="$PERL_PATH/bin:$PATH"

RUN cpm install -L $PERL_PATH App::perlbrew
SHELL ["/bin/bash", "-o", "pipefail", "-c"]

ENV BASH_ENV="$PERL_PATH/perlbrew/etc/bashrc"

# RUN echo "=== $BASH_ENV"
RUN perlbrew init \
&& perlbrew install-patchperl \
&& perlbrew install --notest perl-5.36.0

ENV PATH="$PERL_PATH/perlbrew/perls/perl-5.36.0/bin:$PATH"

# RUN echo $PATH
RUN $PERL_PATH/perlbrew/perls/perl-5.36.0/bin/cpan App::cpm
RUN chown -R $NB_UID $PERL_PATH/..
RUN rm /usr/local/bin/cpm
RUN ls /home/jovyan/perl5/perlbrew/perls/perl-5.36.0/bin
USER $NB_UID

RUN cpm install -L $PERL_PATH Devel::IPerl
RUN cpm install -L $PERL_PATH PDL
COPY perl-modules /tmp/perl-modules
RUN cat /tmp/perl-modules | cpm install - -L $PERL_PATH

RUN rm -fR /home/jovyan/.cpanm/work/* /home/jovyan/.perl-cpm

USER root

RUN apt-get clean && \
    rm -rf /var/lib/apt/lists/* && \
    apt-get purge -y --auto-remove \
        -o APT::AutoRemove::RecommendsImportant=false -o APT::AutoRemove::SuggestsImportant=false $BUILD_DEPS

USER $NB_UID

RUN sed -e 's@/usr/bin/perl@/home/jovyan/perl5/perlbrew/perls/perl-5.36.0/bin/perl@' -i /home/jovyan/perl5/bin/iperl
RUN iperl --help
