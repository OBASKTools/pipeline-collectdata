FROM python:3.6

VOLUME /logs
VOLUME /out

# from compose args
ARG CONF_REPO
ARG CONF_BRANCH

ENV CONF_BASE=/opt/conf_base
ENV CONF_DIR=${CONF_BASE}/config/collectdata

ENV WORKSPACE=/opt/VFB
ENV VOLUMEDATA=/out
ENV VALIDATE=true
ENV VALIDATESHEX=true
# ENV VALIDATESHACL=true
ENV VALIDATESHACL=false
ENV REMOVE_EMBARGOED_DATA=true
ENV REMOVE_UNSAT_CAUSING_AXIOMS=true
# These are potential causes of unsatisfiability:
# DisjointClasses DisjointUnion DifferentIndividuals NegativeObjectPropertyAssertion
# NegativeDataPropertyAssertion FunctionalObjectProperty InverseFunctionalObjectProperty
# ReflexiveObjectProperty IrrefexiveObjectProperty ObjectPropertyDomain ObjectPropertyRange
# DisjointObjectProperties FunctionalDataProperty DataPropertyDomain DataPropertyRange DisjointDataProperties"

ENV UNSAT_AXIOM_TYPES="DisjointClasses DisjointUnion DifferentIndividuals DisjointObjectProperties DisjointDataProperties"

# FOR STAGING, CURRENTLY ONLY prod and dev are supported. If set to dev
# Datasets will only be embargoed if they are not staged.
ENV STAGING=prod

# ENV CHUNK_SIZE=1000
# ENV PING_SLEEP=120s
# ENV BUILD_OUTPUT=${WORKSPACE}/build.out

ENV PATH "/opt/VFB/:/opt/VFB/shacl/bin:$PATH"

# ENV KBuser=neo4j
# ENV KBserver=http://192.168.0.1:7474
# ENV KBpassword=password
ENV VFB_NEO4J_SRC=${WORKSPACE}/VFB_neo4j
# ENV GITBRANCH=kbold2new
ENV GITBRANCH=kbold2new_neo4j_v4

RUN pip3 install wheel requests psycopg2 pandas base36 rdflib

RUN apt-get -qq update || apt-get -qq update && \
apt-get -qq -y install git curl wget default-jdk pigz maven libpq-dev python-dev tree gawk

RUN mkdir $CONF_BASE
RUN mkdir $WORKSPACE

###### REMOTE CONFIG ######
ARG CONF_BASE_TEMP=${CONF_BASE}/temp
RUN mkdir $CONF_BASE_TEMP
RUN cd "${CONF_BASE_TEMP}" && git clone --quiet ${CONF_REPO} && cd $(ls -d */|head -n 1) && git checkout ${CONF_BRANCH}
# copy inner project folder from temp to conf base
RUN cd "${CONF_BASE_TEMP}" && cd $(ls -d */|head -n 1) && cp -R . $CONF_BASE && cd $CONF_BASE && rm -r ${CONF_BASE_TEMP} && tree ${CONF_BASE}

###### ROBOT ######
ENV ROBOT v1.7.0
ENV ROBOT_ARGS -Xmx20G
ARG ROBOT_JAR=https://github.com/ontodev/robot/releases/download/$ROBOT/robot.jar
ENV ROBOT_JAR ${ROBOT_JAR}
RUN wget $ROBOT_JAR -O $WORKSPACE/robot.jar && \
    wget https://raw.githubusercontent.com/ontodev/robot/$ROBOT/bin/robot -O $WORKSPACE/robot && \
    chmod +x $WORKSPACE/robot && chmod +x $WORKSPACE/robot.jar

###### SHACL ######
ENV SHACL_VERSION 1.3.2
ARG SHACL_ZIP=https://repo1.maven.org/maven2/org/topbraid/shacl/$SHACL_VERSION/shacl-$SHACL_VERSION-bin.zip
ENV SHACL_ZIP ${SHACL_ZIP}
RUN wget $SHACL_ZIP -O $WORKSPACE/shacl.zip && \
    unzip $WORKSPACE/shacl.zip -d $WORKSPACE && \
    mv $WORKSPACE/shacl-$SHACL_VERSION $WORKSPACE/shacl && \
    rm $WORKSPACE/shacl.zip && chmod +x $WORKSPACE/shacl/bin/shaclvalidate.sh && chmod +x $WORKSPACE/shacl/bin/shaclinfer.sh

RUN ls -l $WORKSPACE/shacl

###### SHEX ######
ENV SHEX_VERSION 1.1
# RUN cd $WORSKPACE && git clone https://github.com/iovka/shex-java.git && \
#    cd shex-java/shex && mvn clean package && \
#    mvn dependency:build-classpath -Dmdep.includeScope=runtime -Dmdep.outputFile=cp.txt


###### VFB Neo4j Python Libraries ########
ENV PYTHONPATH=${WORKSPACE}/VFB_neo4j/src/
RUN cd "${WORKSPACE}" && git clone --quiet https://github.com/VirtualFlyBrain/VFB_neo4j.git && tree ${WORKSPACE}
RUN cd ${VFB_NEO4J_SRC} && git pull origin master && git checkout ${GITBRANCH} && git pull

###### Copy pipeline files ########
COPY process.sh $WORKSPACE/process.sh
RUN chmod +x $WORKSPACE/process.sh
# COPY /test.ttl $WORKSPACE/

COPY /scripts $WORKSPACE/scripts

CMD ["/opt/VFB/process.sh"]
