FROM alpine:3.4

ENV JAVA_HOME /usr/lib/jvm/default-jvm
RUN apk add --no-cache openjdk8 && \
    ln -sf "${JAVA_HOME}/bin/"* "/usr/bin/"

RUN apk add --no-cache git
RUN apk add --no-cache bash

RUN MAVEN_VERSION=3.3.9 \
 && cd /usr/share \
 && wget -q http://archive.apache.org/dist/maven/maven-3/$MAVEN_VERSION/binaries/apache-maven-$MAVEN_VERSION-bin.tar.gz -O - | tar xzf - \
 && mv /usr/share/apache-maven-$MAVEN_VERSION /usr/share/maven \
 && ln -s /usr/share/maven/bin/mvn /usr/bin/mvn
ENV MAVEN_HOME /usr/share/maven

#setup docker
RUN set -e
RUN sed -e 's;^#http\(.*\)/v3.6/community;http\1/v3.6/community;g' \
     -i /etc/apk/repositories
RUN apk update
RUN apk add docker
RUN memb=$(grep "^docker:" /etc/group | sed -e 's/^.*:\([^:]*\)$/\1/g') [ "${memb}x" = "x" ] && memb=${USER} || memb="${memb},${USER}"
RUN sed -e "s/^docker:\(.*\):\([^:]*\)$/docker:\1:${memb}/g" -i /etc/group

ENV NODE_VERSION 8.10.0

# Install dependencies
RUN addgroup -g 1000 -S leap \
    && adduser -u 1000 -S leap -G leap \
    && apk update \
    && apk upgrade \
    && apk add --no-cache libstdc++ \
    && apk add --no-cache --virtual .build-deps \
    && apk add bash \
        binutils-gold \
        curl \
        g++ \
        gcc \
        git \
        gnupg \
        libgcc \
        linux-headers \
        make \
        python

# Install NodeJS
RUN curl -SLO "https://nodejs.org/dist/v$NODE_VERSION/node-v$NODE_VERSION.tar.xz" \
    && tar -xf "node-v$NODE_VERSION.tar.xz" \
    && cd "node-v$NODE_VERSION" \
    && ./configure \
    && make -j$(getconf _NPROCESSORS_ONLN) \
    && make install \
    && apk del .build-deps \
    && cd .. \
    && rm -Rf "node-v$NODE_VERSION" \
    && rm "node-v$NODE_VERSION.tar.xz"

ENV YARN_VERSION 1.7.0

RUN apk add --no-cache --virtual .build-deps-yarn curl gnupg tar \
  && curl -fSLO --compressed "https://yarnpkg.com/downloads/$YARN_VERSION/yarn-v$YARN_VERSION.tar.gz" \
  && curl -fSLO --compressed "https://yarnpkg.com/downloads/$YARN_VERSION/yarn-v$YARN_VERSION.tar.gz.asc" \
  && gpg --batch --verify yarn-v$YARN_VERSION.tar.gz.asc yarn-v$YARN_VERSION.tar.gz \
  && mkdir -p /opt \
  && tar -xzf yarn-v$YARN_VERSION.tar.gz -C /opt/ \
  && ln -s /opt/yarn-v$YARN_VERSION/bin/yarn /usr/local/bin/yarn \
  && ln -s /opt/yarn-v$YARN_VERSION/bin/yarnpkg /usr/local/bin/yarnpkg \
  && rm yarn-v$YARN_VERSION.tar.gz.asc yarn-v$YARN_VERSION.tar.gz \
  && apk del .build-deps-yarn



RUN curl -O https://bootstrap.pypa.io/get-pip.py && python get-pip.py
RUN pip install awscli --upgrade
RUN npm config set unsafe-perm true
RUN npm install gulp@3.9.1 -g
RUN npm install npm@5.6.0 -g

# Add user jenkins to the image
RUN adduser -D jenkins
# Set password for the jenkins user (you may want to alter this).
RUN echo "jenkins:jenkins" | chpasswd
RUN mkdir /home/jenkins/.m2
RUN chown -R jenkins:jenkins /home/jenkins/.m2/

RUN apk update && apk add sudo
RUN echo "jenkins ALL= (ALL) NOPASSWD: ALL"  >> /etc/sudoers

RUN apk add --no-cache openssh
RUN mkdir -p /var/run/sshd
RUN ssh-keygen -f /etc/ssh/ssh_host_rsa_key -N '' -t rsa
RUN ssh-keygen -f /etc/ssh/ssh_host_dsa_key -N '' -t dsa

COPY git-https-client.crt /var/jenkins_home/keys/git-https-client.crt
COPY git-https-client.key /var/jenkins_home/keys/git-https-client.key

# Install prerequisites for Docker
ENV KUBERNETES_VERSION=v1.8.1
# Set up Kubernetes
RUN apk update ;apk add curl
RUN curl -LO https://storage.googleapis.com/kubernetes-release/release/$KUBERNETES_VERSION/bin/linux/amd64/kubectl
RUN chmod +x ./kubectl
RUN mv ./kubectl /usr/local/bin/kubectl
RUN apk add git

EXPOSE 22
RUN su - jenkins
CMD ["/usr/sbin/sshd","-D"]
