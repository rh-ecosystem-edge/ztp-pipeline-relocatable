FROM centos:stream8

RUN cd /tmp && \
    curl -Ls https://github.com/stedolan/jq/releases/download/jq-1.6/jq-linux64 >/usr/bin/jq && \
    chmod u+x /usr/bin/jq && \
    curl -k -s https://mirror.openshift.com/pub/openshift-v4/clients/ocp/latest/openshift-client-linux.tar.gz >oc.tar.gz && \
    tar zxf oc.tar.gz && \
    rm -rf oc.tar.gz && \
    mv oc /usr/bin && \
    chmod +x /usr/bin/oc && \
    curl -k -s https://mirror.openshift.com/pub/openshift-v4/x86_64/clients/ocp/latest/opm-linux.tar.gz >opm.tar.gz && \
    tar zxf opm.tar.gz && \
    rm -rf opm.tar.gz && \
    mv opm /usr/bin && \
    chmod +x /usr/bin/opm && \
    curl -L https://storage.googleapis.com/kubernetes-release/release/$(curl -s https://storage.googleapis.com/kubernetes-release/release/stable.txt)/bin/linux/amd64/kubectl >/usr/bin/kubectl && \
    chmod u+x /usr/bin/kubectl && \
    curl -s -L https://github.com/mikefarah/yq/releases/download/v4.14.2/yq_linux_amd64 >/usr/bin/yq && \
    chmod +x /usr/bin/yq && \
    curl -L https://storage.googleapis.com/kubernetes-release/release/$(curl -s https://storage.googleapis.com/kubernetes-release/release/stable.txt)/bin/linux/amd64/kubectl >/usr/bin/kubectl && \
    chmod u+x /usr/bin/kubectl

RUN dnf install -y bind-utils openssh-clients httpd-tools conmon skopeo podman && dnf clean all

COPY . /ztp-pipeline
RUN chmod 777 /ztp-pipeline
