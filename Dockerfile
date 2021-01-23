FROM ubuntu

ENV PORT=8443

WORKDIR /home
COPY mutating-webhook .

ENTRYPOINT /home/mutating-webhook
#CMD /mutating-webhook
