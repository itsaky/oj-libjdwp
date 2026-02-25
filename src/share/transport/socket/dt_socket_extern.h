#ifndef __DT_SOCKET_HEADER
#define __DT_SOCKET_HEADER

#include "jni.h"
#include "jdwpTransport.h"

extern jint socketTransport_OnLoad(JavaVM *, jdwpTransportCallback *,
                                   jint, jdwpTransportEnv **);

#endif