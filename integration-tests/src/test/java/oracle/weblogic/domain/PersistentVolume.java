// Copyright (c) 2023, Oracle and/or its affiliates.
// Licensed under the Universal Permissive License v 1.0 as shown at https://oss.oracle.com/licenses/upl.

package oracle.weblogic.domain;

import io.kubernetes.client.openapi.models.V1ObjectMeta;
import io.swagger.annotations.ApiModelProperty;
import org.apache.commons.lang3.builder.EqualsBuilder;
import org.apache.commons.lang3.builder.HashCodeBuilder;
import org.apache.commons.lang3.builder.ToStringBuilder;

public class PersistentVolume {

  /**
   * Standard object's metadata. More info:
   * More info: https://git.k8s.io/community/contributors/devel/sig-architecture/api-conventions.md#metadata
   */
  @SuppressWarnings("common-java:DuplicatedBlocks")
  @ApiModelProperty("The PersistentVolume metadata. Must include the `name` field. Required.")
  private V1ObjectMeta metadata;

  /**
   * PersistentVolumeSpec is a description of a persistent volume.
   */
  @ApiModelProperty("The specification of a persistent volume for `Domain on PV` domain. Required."
      + " This section provides a subset of fields in standard Kubernetes PersistentVolume specifications.")
  private PersistentVolumeSpec spec;

  public V1ObjectMeta getMetadata() {
    return metadata;
  }

  public PersistentVolume metadata(V1ObjectMeta metadata) {
    this.metadata = metadata;
    return this;
  }

  public PersistentVolumeSpec getSpec() {
    return spec;
  }

  public PersistentVolume spec(PersistentVolumeSpec spec) {
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
    } else if (!(other instanceof PersistentVolume)) {
      return false;
    }

    PersistentVolume rhs = ((PersistentVolume) other);
    EqualsBuilder builder =
        new EqualsBuilder()
            .append(metadata, rhs.metadata)
            .append(spec, rhs.spec);

    return builder.isEquals();
  }
}
