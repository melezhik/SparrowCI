docker buildx create --name mybuilder --bootstrap --use
docker buildx build Dockerfiles/ -f Dockerfiles/sparrow.alpine.multi -t melezhik/sparrow:alpine_multi --platform linux/arm64/v8,linux/amd64
