@# Included from rosidl_generator_c/resource/srv__type_support.c.em
@{
from rosidl_parser.definition import SERVICE_EVENT_MESSAGE_SUFFIX
from rosidl_parser.definition import SERVICE_REQUEST_MESSAGE_SUFFIX
from rosidl_parser.definition import SERVICE_RESPONSE_MESSAGE_SUFFIX
from rosidl_pycommon import convert_camel_case_to_lower_case_underscore
event_type = '__'.join([package_name, *interface_path.parents[0].parts, service.namespaced_type.name]) + SERVICE_EVENT_MESSAGE_SUFFIX
request_type = '__'.join([package_name, *interface_path.parents[0].parts, service.namespaced_type.name]) + SERVICE_REQUEST_MESSAGE_SUFFIX
response_type = '__'.join([package_name, *interface_path.parents[0].parts, service.namespaced_type.name]) + SERVICE_RESPONSE_MESSAGE_SUFFIX
}

// Forward declare the get type support functions for this type.
bool
ROSIDL_TYPESUPPORT_INTERFACE__SERVICE_DESTROY_EVENT_MESSAGE_SYMBOL_NAME(
  rosidl_typesupport_c,
  @(',\n  '.join(service.namespaced_type.namespaced_name()))
)(
  void * event_msg,
  rcutils_allocator_t * allocator)
{
  if (!allocator) {
    return false;
  }
  if (NULL == event_msg) {
    return false;
  }
  @event_type * _event_msg = (@event_type *)(event_msg);

  @(event_type)__fini((@event_type *)(_event_msg));
  if (_event_msg->request.data) {
    allocator->deallocate(_event_msg->request.data, allocator->state);
  }
  if (_event_msg->response.data) {
    allocator->deallocate(_event_msg->response.data, allocator->state);
  }
  allocator->deallocate(_event_msg, allocator->state);
  return true;
}
