.PHONY: staging staging-customer prod prod-customer build-prod build-prod-aab rules-staging rules-prod ship-prod

staging:
	./scripts/run_staging.sh partner

staging-customer:
	./scripts/run_staging.sh customer

prod:
	./scripts/run_prod.sh partner

prod-customer:
	./scripts/run_prod.sh customer

build-prod:
	./scripts/build_prod.sh partner apk

build-prod-aab:
	./scripts/build_prod.sh partner aab

rules-staging:
	npx -y firebase-tools@latest deploy --only firestore:rules -P staging

rules-prod:
	npx -y firebase-tools@latest deploy --only firestore:rules -P prod

ship-prod:
	./scripts/deploy_staging_to_prod.sh partner apk
