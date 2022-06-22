// Copyright (c) 2019, 2022, Oracle and/or its affiliates.
// Licensed under the Universal Permissive License v 1.0 as shown at https://oss.oracle.com/licenses/upl.

package oracle.kubernetes.operator.helpers;

import java.util.Arrays;
import java.util.List;
import java.util.Map;
import java.util.stream.Collectors;

import com.meterware.simplestub.Stub;
import io.kubernetes.client.openapi.models.V1Container;
import io.kubernetes.client.openapi.models.V1ObjectMeta;
import io.kubernetes.client.openapi.models.V1Pod;
import io.kubernetes.client.openapi.models.V1PodCondition;
import io.kubernetes.client.openapi.models.V1PodDisruptionBudget;
import io.kubernetes.client.openapi.models.V1PodSpec;
import io.kubernetes.client.openapi.models.V1PodStatus;
import io.kubernetes.client.openapi.models.V1Service;
import oracle.kubernetes.operator.helpers.DomainPresenceInfo.ServerStartupInfo;
import oracle.kubernetes.operator.processing.EffectiveClusterSpec;
import oracle.kubernetes.operator.processing.EffectiveServerSpec;
import oracle.kubernetes.operator.wlsconfig.WlsServerConfig;
import oracle.kubernetes.weblogic.domain.model.ClusterResource;
import oracle.kubernetes.weblogic.domain.model.ClusterSpec;
import oracle.kubernetes.weblogic.domain.model.DomainResource;
import oracle.kubernetes.weblogic.domain.model.DomainSpec;
import org.hamcrest.core.Is;
import org.junit.jupiter.api.Test;

import static oracle.kubernetes.operator.KubernetesConstants.DEFAULT_IMAGE;
import static oracle.kubernetes.operator.LabelConstants.CLUSTERNAME_LABEL;
import static org.hamcrest.CoreMatchers.hasItems;
import static org.hamcrest.CoreMatchers.notNullValue;
import static org.hamcrest.CoreMatchers.nullValue;
import static org.hamcrest.CoreMatchers.sameInstance;
import static org.hamcrest.Matchers.aMapWithSize;
import static org.hamcrest.Matchers.anEmptyMap;
import static org.hamcrest.Matchers.empty;
import static org.hamcrest.Matchers.equalTo;
import static org.hamcrest.Matchers.hasItem;
import static org.hamcrest.junit.MatcherAssert.assertThat;

class DomainPresenceInfoTest {
  private static final String[] MANAGED_SERVER_NAMES = {"ms1", "ms2", "ms3"};
  private static final List<ServerStartupInfo> STARTUP_INFOS = Arrays.stream(MANAGED_SERVER_NAMES)
        .map(DomainPresenceInfoTest::toServerStartupInfo)
        .collect(Collectors.toList());
  private static final String NAMESPACE = "ns";
  private static final String DOMAIN_UID = "domain";
  private final DomainPresenceInfo info = new DomainPresenceInfo(NAMESPACE, DOMAIN_UID);

  private static DomainPresenceInfo createDomainPresenceInfo(DomainResource domain) {
    return new DomainPresenceInfo(domain);
  }

  static DomainResource createDomain(String ns, String domainUid) {
    return new DomainResource()
        .withMetadata(new V1ObjectMeta().namespace(ns))
        .withSpec(
            new DomainSpec().withDomainUid(domainUid));
  }

  private void createAndAddClusterResourceToDomainPresenceInfo(
      DomainPresenceInfo dpi, String clusterName, String domainUid) {
    dpi.addClusterResource(createClusterResource(clusterName, domainUid));
  }

  private ClusterResource createClusterResource(String clusterName, String domain1) {
    return new ClusterResource()
        .spec(createClusterSpec(clusterName, domain1));
  }

  private ClusterSpec createClusterSpec(String clusterName, String domain1) {
    return new ClusterSpec().withClusterName(clusterName).withDomainUid(domain1);
  }

  private static ServerStartupInfo toServerStartupInfo(String serverName) {
    return new ServerStartupInfo(
          new WlsServerConfig(serverName, "host", 7001),
          null,
          Stub.createStub(EffectiveServerSpec.class)
          );
  }

  @Test
  void whenNoneDefined_getClusterServiceReturnsNull() {
    assertThat(info.getClusterService("cluster"), nullValue());
  }

  @Test
  void afterClusterServiceDefined_nextCallReturnsIt() {
    V1Service service = new V1Service();
    info.setClusterService("cluster", service);

    assertThat(info.getClusterService("cluster"), sameInstance(service));
  }

  @Test
  void whenNoneDefined_getServerServiceReturnsNull() {
    assertThat(info.getServerService("admin"), nullValue());
  }

  @Test
  void whenNoServersDefined_getServerStartupInfoReturnsEmptyCollection() {
    assertThat(info.getServerStartupInfo(), empty());
  }

  @Test
  void whenNoServersDefined_expectedRunningServersReturnsEmptyCollection() {
    assertThat(info.getExpectedRunningServers(), empty());
  }

  @Test
  void whenAdminServerNameDefined_expectedRunningServersIncludesAdminServerName() {
    info.setAdminServerName("admin");

    assertThat(info.getExpectedRunningServers(), hasItem("admin"));
  }

  @Test
  void whenServerStartupInfoDefined_expectedRunningServersIncludesDefinedServers() {
    info.setServerStartupInfo(STARTUP_INFOS);

    assertThat(info.getExpectedRunningServers(), hasItems(MANAGED_SERVER_NAMES));
  }

  @Test
  void afterServerServiceDefined_nextCallReturnsIt() {
    V1Service service = new V1Service();
    info.setServerService("admin", service);

    assertThat(info.getServerService("admin"), sameInstance(service));
  }

  @Test
  void whenNoneDefined_getExternalServiceReturnsNull() {
    assertThat(info.getExternalService("admin"), nullValue());
  }

  @Test
  void afterExternalServiceDefined_nextCallReturnsIt() {
    V1Service service = new V1Service();
    info.setExternalService("admin", service);

    assertThat(info.getExternalService("admin"), sameInstance(service));
  }

  @Test
  void whenNoneDefined_getServerPodReturnsNull() {
    assertThat(info.getServerPod("myserver"), nullValue());
  }

  @Test
  void afterServerPodDefined_nextCallReturnsIt() {
    V1Pod pod = new V1Pod();
    info.setServerPod("myserver", pod);

    assertThat(info.getServerPod("myserver"), sameInstance(pod));
  }

  @Test
  void whenNoneDefined_getPodDisruptionBudgetReturnsNull() {
    assertThat(info.getPodDisruptionBudget("cluster"), nullValue());
  }

  @Test
  void afterPodDisruptionBudgetDefined_nextCallReturnsIt() {
    V1PodDisruptionBudget pdb = new V1PodDisruptionBudget();
    info.setPodDisruptionBudget("cluster", pdb);

    assertThat(info.getPodDisruptionBudget("cluster"), sameInstance(pdb));
  }

  @Test
  void countReadyServers() {
    addServer("MS1", "cluster1");
    addReadyServer("MS2", "cluster1");
    addServer("MS3", "cluster2");
    addReadyServer("MS4", "cluster2");
    addServer("MS5", null);
    addReadyServer("MS6", null);

    assertThat(info.getNumReadyServers("cluster1"), equalTo(2L));
    assertThat(info.getNumReadyServers("cluster2"), equalTo(2L));
    assertThat(info.getNumReadyServers(null), equalTo(1L));
  }

  private void addServer(String serverName, String clusterName) {
    info.setServerPod(serverName, createServerInCluster(serverName, clusterName));
  }

  private V1Pod createServerInCluster(String podName, String clusterName) {
    return new V1Pod().metadata(new V1ObjectMeta().name(podName).putLabelsItem(CLUSTERNAME_LABEL, clusterName));
  }

  private void addReadyServer(String serverName, String clusterName) {
    addServer(serverName, clusterName);
    setReady(info.getServerPod(serverName));
  }

  private void setReady(V1Pod pod) {
    pod.status(new V1PodStatus()
          .phase(V1PodStatus.PhaseEnum.RUNNING)
          .addConditionsItem(new V1PodCondition().type(V1PodCondition.TypeEnum.READY).status("True")));

  }

  @Test
  void countScheduledServers() {
    addServer("MS1", "cluster1");
    addScheduledServer("MS2", "cluster1");
    addServer("MS3", "cluster2");
    addScheduledServer("MS4", "cluster2");
    addServer("MS5", null);
    addScheduledServer("MS6", null);

    assertThat(info.getNumScheduledServers("cluster1"), equalTo(2L));
    assertThat(info.getNumScheduledServers("cluster2"), equalTo(2L));
    assertThat(info.getNumScheduledServers(null), equalTo(1L));
  }

  private void addScheduledServer(String serverName, String clusterName) {
    addServer(serverName, clusterName);
    setScheduled(info.getServerPod(serverName));
  }

  private void setScheduled(V1Pod pod) {
    pod.spec(new V1PodSpec().nodeName("aNode"));
  }

  // todo compute availability per cluster: how many servers need to be running, list of servers in cluster

  @Test
  void whenNoneDefined_getClusterResourceReturnsNull() {
    assertThat(info.getClusterResource("cluster-1"), nullValue());
  }

  @Test
  void afterAddingClusterResource_verifyClusterResourceIsNotNull() {
    final String clusterName = "cluster-1";
    final DomainResource domain = createDomain(NAMESPACE, DOMAIN_UID);
    final DomainPresenceInfo info = createDomainPresenceInfo(domain);
    createAndAddClusterResourceToDomainPresenceInfo(info, clusterName, DOMAIN_UID);
    assertThat(info.getClusterResource(clusterName), notNullValue());
    assertThat(info.getClusterResource(clusterName).getDomainUid(), equalTo(DOMAIN_UID));
  }

  @Test
  void afterRemoveClusterResource_verifyClusterResourceIsNull() {
    final String clusterName = "cluster-1";
    final DomainResource domain = createDomain(NAMESPACE, DOMAIN_UID);
    final DomainPresenceInfo info = createDomainPresenceInfo(domain);
    createAndAddClusterResourceToDomainPresenceInfo(info, clusterName, DOMAIN_UID);
    ClusterResource clusterResource = info.removeClusterResource(clusterName);
    assertThat(clusterResource, notNullValue());
    assertThat(info.getClusterResource(clusterName), nullValue());
  }

  @Test
  void whenClusterResourceNotDefined_removeReturnsNull() {
    final String clusterName = "cluster-1";
    ClusterResource clusterResource = info.removeClusterResource(clusterName);
    assertThat(clusterResource, nullValue());
  }

  @Test
  void whenClusterResourceDefined_butServerNotDefined_getEffectiveServerSpec() {
    final String clusterName = "cluster-1";
    final DomainResource domain = createDomain(NAMESPACE, DOMAIN_UID);
    final DomainPresenceInfo info = createDomainPresenceInfo(domain);
    createAndAddClusterResourceToDomainPresenceInfo(info, clusterName, DOMAIN_UID);
    EffectiveServerSpec spec = info.getServer("aServer", clusterName);

    verifyStandardFields(spec);
  }

  // Confirms the value of fields that are constant across the domain
  private void verifyStandardFields(EffectiveServerSpec spec) {
    assertThat(spec.getImage(), equalTo(DEFAULT_IMAGE));
    assertThat(spec.getImagePullPolicy(), equalTo(V1Container.ImagePullPolicyEnum.IFNOTPRESENT));
    assertThat(spec.getImagePullSecrets(), empty());
  }

  //@Test
  void whenClusterResourceDefined_getClusterRestartVersionFromServerSpec() {
    final String clusterName = "cluster-1";
    final String serverName = "managed-server1";
    final String MY_RESTART_VERSION = "MyRestartVersion";

    final DomainResource domain = createDomain(NAMESPACE, DOMAIN_UID);
    final DomainPresenceInfo info = createDomainPresenceInfo(domain);
    createAndAddClusterResourceToDomainPresenceInfo(info, clusterName, DOMAIN_UID);
    info.getClusterResource(clusterName).getSpec().setRestartVersion(MY_RESTART_VERSION);

    EffectiveServerSpec spec = info.getServer(serverName, clusterName);

    verifyStandardFields(spec);
    assertThat(spec.getClusterRestartVersion(), equalTo(MY_RESTART_VERSION));
  }

  @Test
  void whenNonClusteredServerStartPolicyUndefined_startServer() {
    final DomainResource domain = createDomain(NAMESPACE, DOMAIN_UID);
    final DomainPresenceInfo info = createDomainPresenceInfo(domain);
    assertThat(info.getServer("server1", null).shouldStart(0), Is.is(true));
  }

  @Test
  void whenUnconfiguredClusterHasDefaultNumberOfReplicasAndDomainReplicasIs0_dontStartServer() {
    final DomainResource domain = createDomain(NAMESPACE, DOMAIN_UID);
    domain.getSpec().setReplicas(0);
    final DomainPresenceInfo info = createDomainPresenceInfo(domain);
    assertThat(info.getServer("server1", "cls1").shouldStart(0), Is.is(false));
  }

  @Test
  void whenClusterResourceNotDefined_getDefaultEffectiveClusterSpec() {
    final String clusterName = "cluster-1";
    final DomainResource domain = createDomain(NAMESPACE, DOMAIN_UID);
    final DomainPresenceInfo info = createDomainPresenceInfo(domain);

    EffectiveClusterSpec clusterSpec = info.getCluster(clusterName);
    assertThat(clusterSpec.getClusterLabels(), anEmptyMap());
  }

  @Test
  void whenClusterResourceDefined_getEffectiveClusterSpec() {
    final String clusterName = "cluster-1";
    final String labelKey = "Hello";
    final String labelValue = "World";

    final DomainResource domain = createDomain(NAMESPACE, DOMAIN_UID);
    final DomainPresenceInfo info = createDomainPresenceInfo(domain);
    createAndAddClusterResourceToDomainPresenceInfo(info, clusterName, DOMAIN_UID);
    info.getClusterResource(clusterName).getSpec().getClusterLabels().put(labelKey, labelValue);

    EffectiveClusterSpec clusterSpec = info.getCluster(clusterName);
    Map<String,String> labels = clusterSpec.getClusterLabels();
    assertThat(labels, aMapWithSize(1));
    assertThat(labels.get(labelKey), equalTo(labelValue));
  }

}
