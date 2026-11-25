.PHONY: staging staging-customer staging-ios staging-customer-ios \
        prod prod-customer prod-ios prod-customer-ios \
        build-staging build-staging-customer build-prod build-prod-customer build-prod-aab \
        rules-staging rules-prod push ship-prod

staging:
	./gym run --staging

staging-customer:
	./gym run --staging --customer

staging-ios:
	./gym run --staging --ios

staging-customer-ios:
	./gym run --staging --customer --ios

prod:
	./gym run --prod

prod-customer:
	./gym run --prod --customer

prod-ios:
	./gym run --prod --ios

prod-customer-ios:
	./gym run --prod --customer --ios

build-staging:
	./gym build apk --staging

build-staging-customer:
	./gym build apk --staging --customer

build-prod:
	./gym build apk --prod

build-prod-customer:
	./gym build apk --prod --customer

build-prod-aab:
	./gym build aab --prod

rules-staging:
	./gym rules --staging

rules-prod:
	./gym rules --prod

push:
	./gym push

ship-prod:
	./gym ship
