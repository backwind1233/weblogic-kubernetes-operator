// Copyright (c) 2023, Oracle and/or its affiliates.
// Licensed under the Universal Permissive License v 1.0 as shown at https://oss.oracle.com/licenses/upl.

package oracle.weblogic.domain;

import io.kubernetes.client.openapi.models.V1ObjectMeta;
import io.swagger.annotations.ApiModelProperty;
import org.apache.commons.lang3.builder.EqualsBuilder;
import org.apache.commons.lang3.builder.HashCodeBuilder;
import org.apache.commons.lang3.builder.ToStringBuilder;

public class PersistentVolumeClaim {

  /**
   * Standard object's metadata. More info:
   * More info: https://git.k8s.io/community/contributors/devel/sig-architecture/api-conventions.md#metadata
   */
  @SuppressWarnings("common-java:DuplicatedBlocks")
  @ApiModelProperty("The PersistentVolumeClaim metadata. Must include the `name` field. Required.")
  private V1ObjectMeta metadata;

  /**
   * PersistentVolumeClaimSpec is a description of a persistent volume claim.
   */
  @ApiModelProperty("The specifications of a persistent volume claim for `Domain on PV` domain. Required."
      + " This section provides a subset of fields in standard Kubernetes PersistentVolumeClaim specifications.")
  private PersistentVolumeClaimSpec spec;

  public V1ObjectMeta getMetadata() {
    return metadata;
  }

  public PersistentVolumeClaim metadata(V1ObjectMeta metadata) {
    this.metadata = metadata;
    return this;
  }

  public PersistentVolumeClaimSpec getSpec() {
    return spec;
  }

  public PersistentVolumeClaim spec(PersistentVolumeClaimSpec spec) {
    this.spec = spec;
    return this;
  }

  @Override
  public String toString() {
    ToStringBuilder builder =
        new ToStringBuilder(this)
            .append("metadata", metadata)
            .append("spec", spec);

    return builder.toString();
  }

  @Override
  public int hashCode() {
    HashCodeBuilder builder = new HashCodeBuilder()
        .append(metadata)
        .append(spec);

    return builder.toHashCode();
  }

  @Override
  public boolean equals(Object other) {
    if (other == this) {
      return true;
    } else if (!(other instanceof PersistentVolumeClaim)) {
      return false;
    }

    PersistentVolumeClaim rhs = ((PersistentVolumeClaim) other);
    EqualsBuilder builder =
        new EqualsBuilder()
            .append(metadata, rhs.metadata)
            .append(spec, rhs.spec);

    return builder.isEquals();
  }

}
