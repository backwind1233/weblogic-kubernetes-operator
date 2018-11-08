// Copyright 2018, Oracle Corporation and/or its affiliates.  All rights reserved.
// Licensed under the Universal Permissive License v 1.0 as shown at
// http://oss.oracle.com/licenses/upl.

package oracle.kubernetes.json;

import com.google.gson.Gson;
import com.google.gson.GsonBuilder;
import com.google.gson.annotations.SerializedName;
import java.io.BufferedReader;
import java.io.IOException;
import java.io.InputStreamReader;
import java.lang.reflect.Field;
import java.lang.reflect.Modifier;
import java.net.MalformedURLException;
import java.net.URL;
import java.util.ArrayList;
import java.util.Arrays;
import java.util.Collection;
import java.util.HashMap;
import java.util.HashSet;
import java.util.Iterator;
import java.util.List;
import java.util.Map;
import java.util.Set;
import javax.annotation.Nonnull;

@SuppressWarnings("WeakerAccess")
public class SchemaGenerator {
  public static final String DEFAULT_KUBERNETES_VERSION = "1.9.0";

  private static final String EXTERNAL_CLASS = "external";

  private static final List<Class<?>> PRIMITIVE_NUMBERS =
      Arrays.asList(byte.class, short.class, int.class, long.class, float.class, double.class);

  private static final String K8S_SCHEMA_URL =
      "https://github.com/garethr/kubernetes-json-schema/blob/master/v%s/_definitions.json";
  private static final String K8S_SCHEMA_CACHE = "caches/kubernetes-%s.json";

  // A map of classes to their $ref values
  private Map<Class<?>, String> references = new HashMap<>();

  // A map of found classes to their definitions or the constant EXTERNAL_CLASS.
  private Map<Class<?>, Object> definedObjects = new HashMap<>();

  // a map of external class names to the external schema that defines them
  private Map<String, String> schemaUrls = new HashMap<>();
  private boolean includeDeprecated;

  /**
   * Returns a pretty-printed string corresponding to a generated schema
   *
   * @param schema a schema generated by a call to #generate
   * @return a string version of the schema
   */
  public static String prettyPrint(Object schema) {
    return new GsonBuilder().setPrettyPrinting().create().toJson(schema);
  }

  /**
   * Specifies the version of the Kubernetes schema to use.
   *
   * @param version a Kubernetes version string, such as "1.9.0"
   * @throws IOException if no schema for that version is cached.
   */
  public void useKubernetesVersion(String version) throws IOException {
    addExternalSchema(getKubernetesSchemaUrl(version), getKubernetesSchemaCache(version));
  }

  URL getKubernetesSchemaUrl(String version) throws MalformedURLException {
    return new URL(String.format(K8S_SCHEMA_URL, version));
  }

  private URL getKubernetesSchemaCache(String version) {
    return getClass().getResource(String.format(K8S_SCHEMA_CACHE, version));
  }

  public void addExternalSchema(URL schemaUrl) throws IOException {
    addExternalSchema(schemaUrl, new BufferedReader(new InputStreamReader(schemaUrl.openStream())));
  }

  public void addExternalSchema(URL schemaUrl, URL cacheUrl) throws IOException {
    addExternalSchema(schemaUrl, new BufferedReader(new InputStreamReader(cacheUrl.openStream())));
  }

  private void addExternalSchema(URL schemaUrl, BufferedReader schemaReader) throws IOException {
    StringBuilder sb = new StringBuilder();
    String inputLine;
    while ((inputLine = schemaReader.readLine()) != null) sb.append(inputLine).append('\n');
    schemaReader.close();

    Map<String, Map<String, Object>> map = fromJson(sb.toString());
    Map<String, Object> definitions = map.get("definitions");
    for (Map.Entry<String, Object> entry : definitions.entrySet()) {
      if (isDefinitionToUse(entry.getValue())) schemaUrls.put(entry.getKey(), schemaUrl.toString());
    }
  }

  @SuppressWarnings("unchecked")
  private boolean isDefinitionToUse(Object def) {
    Map<String, Object> definition = (Map<String, Object>) def;
    return !isDeprecated(definition.get("description"));
  }

  private boolean isDeprecated(Object description) {
    return description != null && description.toString().contains("Deprecated");
  }

  @SuppressWarnings("unchecked")
  private <T, S> Map<T, S> fromJson(String json) {
    return new Gson().fromJson(json, HashMap.class);
  }

  /**
   * Specifies whether deprecated fields should be included in the schema
   *
   * @param includeDeprecated true to include deprecated fields. Defaults to false.
   */
  public void setIncludeDeprecated(boolean includeDeprecated) {
    this.includeDeprecated = includeDeprecated;
  }

  /**
   * Generates an object representing a JSON schema for the specified class.
   *
   * @param aClass the class for which the schema should be generated
   * @return a map of maps, representing the computed JSON
   */
  public Object generate(Class aClass) {
    Map<String, Object> result = new HashMap<>();

    generateObjectTypeIn(result, aClass);
    if (!definedObjects.isEmpty()) {
      Map<String, Object> definitions = new HashMap<>();
      result.put("definitions", definitions);
      for (Class<?> type : definedObjects.keySet())
        if (!definedObjects.get(type).equals(EXTERNAL_CLASS))
          definitions.put(getDefinitionKey(type), definedObjects.get(type));
    }

    return result;
  }

  void generateFieldIn(Map<String, Object> map, Field field) {
    if (includeInSchema(field)) {
      map.put(getPropertyName(field), getSubSchema(field));
    }
  }

  private boolean includeInSchema(Field field) {
    return !isStatic(field) && !ignoreAsDeprecated(field);
  }

  private boolean isStatic(Field field) {
    return Modifier.isStatic(field.getModifiers());
  }

  private boolean ignoreAsDeprecated(Field field) {
    return !includeDeprecated && field.getAnnotation(Deprecated.class) != null;
  }

  private String getPropertyName(Field field) {
    SerializedName serializedName = field.getAnnotation(SerializedName.class);
    if (serializedName != null && serializedName.value().length() > 0)
      return serializedName.value();
    else return field.getName();
  }

  private Object getSubSchema(Field field) {
    Map<String, Object> result = new HashMap<>();

    SubSchemaGenerator sub = new SubSchemaGenerator(field);

    sub.generateTypeIn(result, field.getType());
    String description = getDescription(field);
    if (description != null) result.put("description", description);

    return result;
  }

  private String getDescription(Field field) {
    Description description = field.getAnnotation(Description.class);
    return description != null ? description.value() : null;
  }

  private class SubSchemaGenerator {
    Field field;

    SubSchemaGenerator(Field field) {
      this.field = field;
    }

    private void generateTypeIn(Map<String, Object> result, Class<?> type) {
      if (type.equals(Boolean.class) || type.equals(Boolean.TYPE)) result.put("type", "boolean");
      else if (Number.class.isAssignableFrom(type) || PRIMITIVE_NUMBERS.contains(type))
        result.put("type", "number");
      else if (type.equals(String.class)) result.put("type", "string");
      else if (type.isEnum()) generateEnumTypeIn(result, type);
      else if (type.isArray()) this.generateArrayTypeIn(result, type);
      else if (Collection.class.isAssignableFrom(type)) generateCollectionTypeIn(result);
      else generateObjectFieldIn(result, type);
    }

    private void generateObjectFieldIn(Map<String, Object> result, Class<?> type) {
      addReference(type);
      result.put("$ref", getReferencePath(type));
    }

    private void generateCollectionTypeIn(Map<String, Object> result) {
      Map<String, Object> items = new HashMap<>();
      result.put("type", "array");
      result.put("items", items);
      generateTypeIn(items, getGenericComponentType());
    }

    private Class<?> getGenericComponentType() {
      try {
        String typeName = field.getGenericType().getTypeName();
        String className = typeName.substring(typeName.indexOf("<") + 1, typeName.indexOf(">"));
        return field.getDeclaringClass().getClassLoader().loadClass(className);
      } catch (ClassNotFoundException e) {
        return Object.class;
      }
    }

    private void generateArrayTypeIn(Map<String, Object> result, Class<?> type) {
      Map<String, Object> items = new HashMap<>();
      result.put("type", "array");
      result.put("items", items);
      generateTypeIn(items, type.getComponentType());
    }
  }

  private void addReference(Class<?> type) {
    if (definedObjects.containsKey(type)) return;
    if (addedKubernetesClass(type)) return;

    Map<String, Object> definition = new HashMap<>();
    definedObjects.put(type, definition);
    references.put(type, "#/definitions/" + getDefinitionKey(type));
    generateObjectTypeIn(definition, type);
  }

  private boolean addedKubernetesClass(Class<?> theClass) {
    if (!theClass.getName().startsWith("io.kubernetes.client")) return false;

    for (String externalName : schemaUrls.keySet()) {
      if (KubernetesApiNames.matches(externalName, theClass)) {
        String schemaUrl = schemaUrls.get(externalName);
        definedObjects.put(theClass, EXTERNAL_CLASS);
        references.put(theClass, schemaUrl + "#/definitions/" + externalName);
        return true;
      }
    }

    return false;
  }

  private String getReferencePath(Class<?> type) {
    return references.get(type);
  }

  private String getDefinitionKey(Class<?> type) {
    return type.getSimpleName();
  }

  private void generateEnumTypeIn(Map<String, Object> result, Class<?> enumType) {
    result.put("type", "string");
    result.put("enum", getEnumValues(enumType));
  }

  private String[] getEnumValues(Class<?> enumType) {
    List<String> values = new ArrayList<>();

    for (Object enumConstant : enumType.getEnumConstants()) {
      values.add(enumConstant.toString());
    }

    return values.toArray(new String[0]);
  }

  private void generateObjectTypeIn(Map<String, Object> result, Class<?> type) {
    Map<String, Object> properties = new HashMap<>();
    List<String> requiredFields = new ArrayList<>();
    result.put("type", "object");
    result.put("additionalProperties", "false");
    result.put("properties", properties);

    for (Field field : getPropertyFields(type)) {
      if (!isSelfReference(field)) generateFieldIn(properties, field);
      if (isRequired(field) && includeInSchema(field)) {
        requiredFields.add(getPropertyName(field));
      }
    }

    if (!requiredFields.isEmpty()) result.put("required", requiredFields.toArray(new String[0]));
  }

  private Collection<Field> getPropertyFields(Class<?> type) {
    Set<Field> result = new HashSet<>();
    for (Class<?> cl = type; cl != null && !cl.equals(Object.class); cl = cl.getSuperclass())
      result.addAll(Arrays.asList(cl.getDeclaredFields()));

    for (Iterator<Field> each = result.iterator(); each.hasNext(); )
      if (isSelfReference(each.next())) each.remove();

    return result;
  }

  private boolean isSelfReference(Field field) {
    return field.getName().startsWith("this$");
  }

  private boolean isRequired(Field field) {
    return isPrimitive(field) || isNonNull(field);
  }

  private boolean isPrimitive(Field field) {
    return field.getType().isPrimitive();
  }

  private boolean isNonNull(Field field) {
    return field.getAnnotation(Nonnull.class) != null;
  }
}
