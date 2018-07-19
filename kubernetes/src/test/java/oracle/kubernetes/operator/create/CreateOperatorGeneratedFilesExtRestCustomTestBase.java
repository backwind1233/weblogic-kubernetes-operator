// Copyright 2018, Oracle Corporation and/or its affiliates.  All rights reserved.
// Licensed under the Universal Permissive License v 1.0 as shown at
// http://oss.oracle.com/licenses/upl.

package oracle.kubernetes.operator.create;

import io.kubernetes.client.models.V1Service;
import oracle.kubernetes.operator.utils.OperatorYamlFactory;

/**
 * Tests that the artifacts in the yaml files that create-weblogic-operator.sh creates are correct
 * when external rest uses custom certs and all other optional features are disabled.
 */
public abstract class CreateOperatorGeneratedFilesExtRestCustomTestBase
    extends CreateOperatorGeneratedFilesTestBase {

  protected static void defineOperatorYamlFactory(OperatorYamlFactory factory) throws Exception {
    setup(factory, factory.newOperatorValues().setupExternalRestCustomCert());
  }

  @Override
  protected String getExpectedExternalWeblogicOperatorCert() {
    return getInputs().externalOperatorCustomCertPem();
  }

  @Override
  protected String getExpectedExternalWeblogicOperatorKey() {
    return getInputs().externalOperatorCustomKeyPem();
  }

  @Override
  protected V1Service getExpectedExternalWeblogicOperatorService() {
    return getExpectedExternalWeblogicOperatorService(false, true);
  }
}
