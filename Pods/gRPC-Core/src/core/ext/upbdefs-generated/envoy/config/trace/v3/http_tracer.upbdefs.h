/* This file was generated by upbc (the upb compiler) from the input
 * file:
 *
 *     envoy/config/trace/v3/http_tracer.proto
 *
 * Do not edit -- your changes will be discarded when the file is
 * regenerated. */

#ifndef ENVOY_CONFIG_TRACE_V3_HTTP_TRACER_PROTO_UPBDEFS_H_
#define ENVOY_CONFIG_TRACE_V3_HTTP_TRACER_PROTO_UPBDEFS_H_

#include "upb/def.h"
#include "upb/port_def.inc"
#ifdef __cplusplus
extern "C" {
#endif

#include "upb/def.h"

#include "upb/port_def.inc"

extern upb_def_init envoy_config_trace_v3_http_tracer_proto_upbdefinit;

UPB_INLINE const upb_msgdef *envoy_config_trace_v3_Tracing_getmsgdef(upb_symtab *s) {
  _upb_symtab_loaddefinit(s, &envoy_config_trace_v3_http_tracer_proto_upbdefinit);
  return upb_symtab_lookupmsg(s, "envoy.config.trace.v3.Tracing");
}

UPB_INLINE const upb_msgdef *envoy_config_trace_v3_Tracing_Http_getmsgdef(upb_symtab *s) {
  _upb_symtab_loaddefinit(s, &envoy_config_trace_v3_http_tracer_proto_upbdefinit);
  return upb_symtab_lookupmsg(s, "envoy.config.trace.v3.Tracing.Http");
}

#ifdef __cplusplus
}  /* extern "C" */
#endif

#include "upb/port_undef.inc"

#endif  /* ENVOY_CONFIG_TRACE_V3_HTTP_TRACER_PROTO_UPBDEFS_H_ */
