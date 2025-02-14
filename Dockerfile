# Docker Compose excerpt with bind mount points:
#
# 	command: mvn -f <POM file relative to project folder> ...
# 	volumes:
# 	- ${TNS_ADMIN}:/opt/oracle/network/admin:ro
# 	- ${HOME}/.m2:/home/pato/.m2
# 	- <your db conf folder (pato-gui --db-config-dir)>:/mnt/db-config:ro
# 	- <your project folder (pato-gui --project-dir)>:/mnt/project
# 	- [ <your oracle-tools project folder (pato-gui --oracle-tools-dir)>:/mnt/oracle-tools:ro ]
# 

ARG VERSION_DEVBOX=0.13.4
ARG VERSION_ALPINE=3.20.3

ARG UID=1000
ARG GID=1000

# ---
# Stage 1 (base): install devbox and its packages
# ---
FROM jetpackio/devbox:${VERSION_DEVBOX} as base

ENV ORACLE_HOME=/opt/oracle
ENV TNS_ADMIN=${ORACLE_HOME}/network/admin

WORKDIR ${TNS_ADMIN}

# Installing your devbox project
USER root:root
WORKDIR /mnt
WORKDIR /app/conf
WORKDIR /app
RUN ln -s /app/conf /mnt/db-config && \
		ln -s /app      /mnt/oracle-tools && \
		ln -s /app      /mnt/project && \
		chown ${DEVBOX_USER}:${DEVBOX_USER} /app
USER ${DEVBOX_USER}:${DEVBOX_USER}
COPY --chown=${DEVBOX_USER}:${DEVBOX_USER} devbox.json devbox.lock ./

RUN devbox run -- echo "Installed Packages."

# Copy all the run time dependencies of python into /tmp/nix-store-closure.
# 1. Assumes that all packages in devbox.json are specified as:
#    a. * <url>#<package name>
#    b. * <package name>@<version>
# 2. maven package has program mvn to look for
RUN programs_a=$(devbox list -q | grep '#' | cut -d '#' -f 2 | sed 's/maven/mvn/') && \
		programs_b=$(devbox list -q | grep '@' | cut -d '@' -f 1 | sed 's/^..//') && \
		echo "programs: ${programs_a} ${programs_b}" && \
		program_locations=$(echo ${programs_a} ${programs_b} | xargs devbox run -- type 2>/dev/null | awk '{print $3}') && \
		deps=$(nix-store -qR ${program_locations}) && \
		mkdir /tmp/nix-store-closure && \
		cp -R $deps /tmp/nix-store-closure

# ---
# Stage 2 (final): create a minimal image based on alpine (having /bin/sh)
# ---
ARG VERSION_ALPINE
FROM alpine:${VERSION_ALPINE} as final

# re-import these arguments
ARG UID
ARG GID

ENV DEVBOX_USER=pato
RUN addgroup --system ${DEVBOX_USER} --gid ${GID} && \
    adduser --uid ${UID} --system --ingroup ${DEVBOX_USER} ${DEVBOX_USER} && \
		test -d /home/${DEVBOX_USER}

USER ${DEVBOX_USER}:${DEVBOX_USER}

WORKDIR /app

# Copy the runtime dependencies into /nix/store
# Note we don't actually have nix installed on this container. But that's fine,
# we don't need it, the built code only relies on the given files existing, not
# Nix.
COPY --from=base --chown=${DEVBOX_USER}:${DEVBOX_USER} /tmp/nix-store-closure /nix/store
COPY --from=base --chown=${DEVBOX_USER}:${DEVBOX_USER} /app/.devbox/nix/profile/default/bin /app/.devbox/nix/profile/default/bin
COPY --from=base /mnt /mnt

ENV PATH=/app/.devbox/nix/profile/default/bin:${PATH}

# Only copy sources necessary for Maven builds
COPY pom.xml ./
# pato-gui --db-config-dir parameter
COPY conf ./conf
COPY db ./db
COPY apex ./apex
COPY .mvn ./.mvn

WORKDIR /mnt/project

CMD ["/bin/sh"]
