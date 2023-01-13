
# Building docker image
VERSION = "v0.0.7" 
IM=matentzn/vfb-pipeline-collectdata
PW=neo4j/neo
OUTDIR=~/data/pipeline2
KB=http://kb.p2.virtualflybrain.org

docker-build:
	@docker build --no-cache -t $(IM):$(VERSION) . \
	&& docker tag $(IM):$(VERSION) $(IM):latest
	
docker-build-use-cache:
	@docker build -t $(IM):$(VERSION) . \
	&& docker tag $(IM):$(VERSION) $(IM):latest

docker-run:
	docker run --volume $(OUTDIR):/out --env=KBpassword=$(PW) --env=KBserver=$(KB) --env=ROBOT_JAVA_ARGS='-Xmx11G' $(IM)

docker-clean:
	docker kill $(IM) || echo not running ;
	docker rm $(IM) || echo not made 

docker-publish-no-build:
	@docker push $(IM):$(VERSION) \
	&& docker push $(IM):latest
	
docker-publish: docker-build-use-cache
	@docker push $(IM):$(VERSION) \
	&& docker push $(IM):latest

QUERY=PREFIX%20rdfs%3A%20%3Chttp%3A%2F%2Fwww.w3.org%2F2000%2F01%2Frdf-schema%23%3E%0APREFIX%20owl%3A%20%3Chttp%3A%2F%2Fwww.w3.org%2F2002%2F07%2Fowl%23%3E%0APREFIX%20n2o%3A%20%3Chttp%3A%2F%2Fn2o.neo%2Fproperty%2F%3E%0APREFIX%20n2oc%3A%20%3Chttp%3A%2F%2Fn2o.neo%2Fcustom%2F%3E%0APREFIX%20dct%3A%20%3Chttp%3A%2F%2Fpurl.org%2Fdc%2Fterms%2F%3E%0A%0ACONSTRUCT%20%7B%0A%20%20%3Fdataset%20%3Fdsrel%20%3Fdsval%20.%20%0A%09%3Fimage%20%3Fimgrel%20%3Fimgval%20.%0A%09%3Fchannel%20%3Fchannelrel%20%3Fchannelval%20.%0A%7D%0A%0A%09WHERE%20%7B%0A%09%0A%09%3Fdataset%20n2o%3AnodeLabel%20%3Fnodelabel%20.%20%23%20This%20selects%20all%20datasets%0A%09%0A%09OPTIONAL%20%7B%0A%20%20%09%3Fdataset%20n2oc%3Aproduction%20%3Fproduction%20.%0A%09%09%23%20n2oc%3Aproduction%20is%20a%20bit%20brittle%20because%20IRI%20might%20be%20changed%20%28risk%21%29%0A%09%7D%0A%09%0A%09%3Fdataset%20%3Fdsrel%20%3Fdsval%20.%0A%20%20%0A%20%20OPTIONAL%20%7B%0A%20%20%09%20%3Fimage%20dct%3Asource%20%3Fdataset%20.%20%23in%20case%20a%20dataset%20does%20not%20have%20images%20yet%20this%20is%20an%20optional%20clause%0A%09%09%20%3Fimage%20%3Fimgrel%20%3Fimgval%20.%0A%09%7D%0A%20%20%0A%20%20OPTIONAL%20%7B%0A%20%20%09%3Fchannel%20%3Chttp%3A%2F%2Fxmlns.com%2Ffoaf%2F0.1%2Fdepicts%3E%20%3Fimage%20.%20%23%20There%20does%20not%20always%20seem%20to%20be%20a%20channel%0A%09%09%3Fchannel%20%3Fchannelrel%20%3Fchannelval%20.%0A%20%20%7D%0A%09%0A%20%20FILTER%28%3Fproduction%3Dfalse%20%7C%7C%20%21bound%28%3Fproduction%29%29%20.%0A%20%20FILTER%28%3Fnodelabel%3D%22DataSet%22%29%20%0A%7D

TSQ=http://ts.p2.virtualflybrain.org/rdf4j-server/repositories/vfb?query=$(QUERY)

test_query:
	wget $TSQ -O embargo.ttl