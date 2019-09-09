//
//  CYGLDefines.h
//  CYGLPlayer
//
//  Created by Gocy on 2019/9/9.
//  Copyright © 2019 Gocy. All rights reserved.
//

#ifndef CYGLDefines_h
#define CYGLDefines_h

typedef struct {
    float Position[3];
    float TextureCoords[2];
} CoordInfo;

#define CY_GET_GLERROR()                                                 \
{                                                                       \
GLenum err = glGetError();                                          \
while (err != GL_NO_ERROR) {                                        \
NSLog(@"GLError %s set in File:%s Line:%d err = %d\n",          \
GetGLErrorString(err), __FILE__, __LINE__, err);             \
err = glGetError();                                             \
}                                                                   \
}


static inline const char * GetGLErrorString(GLenum error) {
    const char *str;
    switch(error) {
        case GL_NO_ERROR:
            str = "GL_NO_ERROR";
            break;
        case GL_INVALID_ENUM:
            str = "GL_INVALID_ENUM";
            break;
        case GL_INVALID_VALUE:
            str = "GL_INVALID_VALUE";
            break;
        case GL_INVALID_OPERATION:
            str = "GL_INVALID_OPERATION";
            break;
#if defined __gl_h_ || defined __gl3_h_
        case GL_OUT_OF_MEMORY:
            str = "GL_OUT_OF_MEMORY";
            break;
        case GL_INVALID_FRAMEBUFFER_OPERATION:
            str = "GL_INVALID_FRAMEBUFFER_OPERATION";
            break;
#endif
#if defined __gl_h_
        case GL_STACK_OVERFLOW:
            str = "GL_STACK_OVERFLOW";
            break;
        case GL_STACK_UNDERFLOW:
            str = "GL_STACK_UNDERFLOW";
            break;
        case GL_TABLE_TOO_LARGE:
            str = "GL_TABLE_TOO_LARGE";
            break;
#endif
        default:
            str = "(ERROR: Unknown Error Enum)";
            break;
    }
    return str;
}


#endif /* CYGLDefines_h */
