.PHONY: $(MAKECMDGOALS)
.EXPORT_ALL_VARIABLES:

namespace_export_var_present:											# Ensure that env var NAMESPACE_EXPORT is present
ifndef NAMESPACE_EXPORT
	$(error NAMESPACE_EXPORT is undefined)
endif

release_name_export_var_present:										# Ensure that env var RELEASE_NAME_EXPORT is present
ifndef RELEASE_NAME_EXPORT
	$(error RELEASE_NAME_EXPORT is undefined)
endif

namespace_import_var_present:											# Ensure that env var NAMESPACE_IMPORT is present
ifndef NAMESPACE_IMPORT
	$(error NAMESPACE_IMPORT is undefined)
endif

release_name_import_var_present:										# Ensure that env var RELEASE_NAME_IMPORT is present
ifndef RELEASE_NAME_IMPORT
	$(error RELEASE_NAME_IMPORT is undefined)
endif

# `make data_migration NAMESPACE_EXPORT=prd RELEASE_NAME_EXPORT=doyoueventrack-prd NAMESPACE_IMPORT=acc RELEASE_NAME_IMPORT=doyoueventrack-acc`
data_migration: namespace_export_var_present release_name_export_var_present namespace_import_var_present release_name_import_var_present
	$(eval FRONTEND_HOST=$(shell kubectl -n ${NAMESPACE_IMPORT} get \
	`kubectl -n ${NAMESPACE_IMPORT} get ingress -l app.kubernetes.io/name=frontend,app.kubernetes.io/instance=${RELEASE_NAME_IMPORT} -o name` \
	-o=jsonpath='{.spec.rules[0].host}'))
	$(eval JOB_LABEL=$(shell echo "job=data-migration"))
	kubectl -n ${NAMESPACE_IMPORT} delete jobs -l ${JOB_LABEL} --field-selector status.successful=1; true
	for f in tools/data-migration/*.yaml; do envsubst '$${NAMESPACE_EXPORT} $${RELEASE_NAME_EXPORT} $${NAMESPACE_IMPORT} $${RELEASE_NAME_IMPORT} $${FRONTEND_HOST}' < $${f} | kubectl apply -f -; done
	timeout 1m bash -c 'until kubectl -n ${NAMESPACE_IMPORT} get pod -l ${JOB_LABEL} -o=jsonpath='{.items[0].metadata.name}' >/dev/null 2>&1; do sleep 1; done'
	kubectl -n ${NAMESPACE_IMPORT} wait --for=condition=ready pod -l ${JOB_LABEL}
	kubectl -n ${NAMESPACE_IMPORT} logs -l ${JOB_LABEL} --follow
	kubectl -n ${NAMESPACE_IMPORT} get po -l ${JOB_LABEL} --no-headers -o=jsonpath='{.items[].status.containerStatuses[].state.terminated.exitCode}' | grep -q '0' || exit 1

update:
	@pip3 list | grep ruamel | grep -q 0.17.32 || pip3 install ruamel.yaml
	python3 tools/update.py -e ${ENV} -a ${APP} -v ${VERSION}