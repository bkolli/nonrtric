/*-
 * ========================LICENSE_START=================================
 * O-RAN-SC
 * %%
 * Copyright (C) 2019 Nordix Foundation
 * %%
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *      http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 * ========================LICENSE_END===================================
 */
package org.oransc.ric.portal.dashboard.controller;

import java.lang.invoke.MethodHandles;

import javax.servlet.http.HttpServletResponse;

import com.google.gson.Gson;
import com.google.gson.GsonBuilder;

import org.oransc.ric.portal.dashboard.DashboardApplication;
import org.oransc.ric.portal.dashboard.DashboardConstants;
import org.oransc.ric.portal.dashboard.exceptions.HttpBadRequestException;
import org.oransc.ric.portal.dashboard.exceptions.HttpInternalServerErrorException;
import org.oransc.ric.portal.dashboard.exceptions.HttpNotFoundException;
import org.oransc.ric.portal.dashboard.exceptions.HttpNotImplementedException;
import org.oransc.ric.portal.dashboard.model.PolicyInstances;
import org.oransc.ric.portal.dashboard.model.PolicyTypes;
import org.oransc.ric.portal.dashboard.model.SuccessTransport;
import org.oransc.ric.portal.dashboard.policyagentapi.PolicyAgentApi;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.http.HttpStatus;
import org.springframework.http.MediaType;
import org.springframework.security.access.annotation.Secured;
import org.springframework.util.Assert;
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import io.swagger.annotations.ApiOperation;

/**
 * Proxies calls from the front end to the Policy agent API.
 *
 * If a method throws RestClientResponseException, it is handled by
 * {@link CustomResponseEntityExceptionHandler#handleProxyMethodException(Exception, org.springframework.web.context.request.WebRequest)}
 * which returns status 502. All other exceptions are handled by Spring which
 * returns status 500.
 */
@RestController
@RequestMapping(value = PolicyController.CONTROLLER_PATH, produces = MediaType.APPLICATION_JSON_VALUE)
public class PolicyController {

	private static final Logger logger = LoggerFactory.getLogger(MethodHandles.lookup().lookupClass());
	private static Gson gson = new GsonBuilder() //
			.serializeNulls() //
			.create(); //

	// Publish paths in constants so tests are easy to write
	public static final String CONTROLLER_PATH = DashboardConstants.ENDPOINT_PREFIX + "/policy";
	// Endpoints
	public static final String VERSION_METHOD = DashboardConstants.VERSION_METHOD;
	public static final String POLICY_TYPES_METHOD = "policytypes";
	public static final String POLICY_TYPE_ID_NAME = "policy_type_id";
	public static final String POLICIES_NAME = "policies";
	public static final String POLICY_INSTANCE_ID_NAME = "policy_instance_id";

	// Populated by the autowired constructor
	private final PolicyAgentApi policyAgentApi;

	@Autowired
	public PolicyController(final PolicyAgentApi policyAgentApi) {
		Assert.notNull(policyAgentApi, "API must not be null");
		this.policyAgentApi = policyAgentApi;
		logger.debug("ctor: configured with client type {}", policyAgentApi.getClass().getName());
	}

	/*
	 * The fields are defined in the Policy Control Typescript interface.
	 */
	@ApiOperation(value = "Gets the policy types from Near Realtime-RIC")
	@GetMapping(POLICY_TYPES_METHOD)
	@Secured({ DashboardConstants.ROLE_ADMIN, DashboardConstants.ROLE_STANDARD })
	public PolicyTypes getAllPolicyTypes(HttpServletResponse response) {
		logger.debug("getAllPolicyTypes");
		return this.policyAgentApi.getAllPolicyTypes();
	}

	@ApiOperation(value = "Returns the policy instances for the given policy type.")
	@GetMapping(POLICY_TYPES_METHOD + "/{" + POLICY_TYPE_ID_NAME + "}/" + POLICIES_NAME)
	@Secured({ DashboardConstants.ROLE_ADMIN, DashboardConstants.ROLE_STANDARD })
	public String getPolicyInstances(@PathVariable(POLICY_TYPE_ID_NAME) String policyTypeIdString) {
		logger.debug("getPolicyInstances {}", policyTypeIdString);

		PolicyInstances i = this.policyAgentApi.getPolicyInstancesForType(policyTypeIdString);
		String json = gson.toJson(i);
		return json;
	}

	@ApiOperation(value = "Returns a policy instance of a type")
	@GetMapping(POLICY_TYPES_METHOD + "/{" + POLICY_TYPE_ID_NAME + "}/" + POLICIES_NAME + "/{" + POLICY_INSTANCE_ID_NAME
			+ "}")
	@Secured({ DashboardConstants.ROLE_ADMIN, DashboardConstants.ROLE_STANDARD })
	public String getPolicyInstance(@PathVariable(POLICY_TYPE_ID_NAME) String policyTypeIdString,
			@PathVariable(POLICY_INSTANCE_ID_NAME) String policyInstanceId) {
		logger.debug("getPolicyInstance {}:{}", policyTypeIdString, policyInstanceId);
		return this.policyAgentApi.getPolicyInstance(policyInstanceId);
	}

	@ApiOperation(value = "Creates the policy instances for the given policy type.")
	@PutMapping(POLICY_TYPES_METHOD + "/{" + POLICY_TYPE_ID_NAME + "}/" + POLICIES_NAME + "/{" + POLICY_INSTANCE_ID_NAME
			+ "}")
	@Secured({ DashboardConstants.ROLE_ADMIN })
	public void putPolicyInstance(@PathVariable(POLICY_TYPE_ID_NAME) String policyTypeIdString,
			@PathVariable(POLICY_INSTANCE_ID_NAME) String policyInstanceId, @RequestBody String instance) {
		logger.debug("putPolicyInstance typeId: {}, instanceId: {}, instance: {}", policyTypeIdString, policyInstanceId,
				instance);
		this.policyAgentApi.putPolicy(policyTypeIdString, policyInstanceId, instance);
	}

	@ApiOperation(value = "Deletes the policy instances for the given policy type.")
	@DeleteMapping(POLICY_TYPES_METHOD + "/{" + POLICY_TYPE_ID_NAME + "}/" + POLICIES_NAME + "/{"
			+ POLICY_INSTANCE_ID_NAME + "}")
	@Secured({ DashboardConstants.ROLE_ADMIN })
	public void deletePolicyInstance(@PathVariable(POLICY_TYPE_ID_NAME) String policyTypeIdString,
			@PathVariable(POLICY_INSTANCE_ID_NAME) String policyInstanceId) {
		logger.debug("deletePolicyInstance typeId: {}, instanceId: {}", policyTypeIdString, policyInstanceId);
		this.policyAgentApi.deletePolicy(policyInstanceId);
	}

	private void checkHttpError(String httpCode) {
		logger.debug("Http Response Code: {}", httpCode);
		if (httpCode.equals(String.valueOf(HttpStatus.NOT_FOUND.value()))) {
			logger.error("Caught HttpNotFoundException");
			throw new HttpNotFoundException("Not Found Exception");
		} else if (httpCode.equals(String.valueOf(HttpStatus.BAD_REQUEST.value()))) {
			logger.error("Caught HttpBadRequestException");
			throw new HttpBadRequestException("Bad Request Exception");
		} else if (httpCode.equals(String.valueOf(HttpStatus.INTERNAL_SERVER_ERROR.value()))) {
			logger.error("Caught HttpInternalServerErrorException");
			throw new HttpInternalServerErrorException("Internal Server Error Exception");
		} else if (httpCode.equals(String.valueOf(HttpStatus.NOT_IMPLEMENTED.value()))) {
			logger.error("Caught HttpNotImplementedException");
			throw new HttpNotImplementedException("Not Implemented Exception");
		}
	}
}