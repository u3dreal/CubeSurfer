#cython: profile=False
#cython: boundscheck=False
#cython: cdivision=True

# NOTE: order of slow fonction to be optimize/multithreaded: kdtreesearching , kdtreecreating , linksolving 

cimport cython
import time
from libc.math cimport sin , ceil , floor , fabs
from cython.parallel import parallel , prange , threadid
from libc.stdlib cimport malloc , realloc, free , rand , srand
from libc.stdio cimport printf

ctypedef float (*f_type)(Test)nogil

cdef extern from *:
    int INT_MIN
    int INT_MAX
    long LONG_MIN
    long LONG_MAX
    float FLT_MIN
    float FLT_MAX

cdef extern from "stdlib.h":
    ctypedef void const_void "const void"
    void qsort(void *base, int nmemb, int size,int(*compar)(const_void *, const_void *)) nogil


cdef int *cytrimem = NULL
cdef int *cytrinum = NULL
cdef float ****cytriangles = NULL
cdef float *cysend = NULL
cdef Particle *cypar = NULL
cdef unsigned int cyparnum = 0


cdef int *edgetable=[0x0, 0x109, 0x203, 0x30a, 0x406, 0x50f, 0x605, 0x70c,
                                0x80c, 0x905, 0xa0f, 0xb06, 0xc0a, 0xd03, 0xe09, 0xf00,
                                0x190, 0x99 , 0x393, 0x29a, 0x596, 0x49f, 0x795, 0x69c,
                                0x99c, 0x895, 0xb9f, 0xa96, 0xd9a, 0xc93, 0xf99, 0xe90,
                                0x230, 0x339, 0x33 , 0x13a, 0x636, 0x73f, 0x435, 0x53c,
                                0xa3c, 0xb35, 0x83f, 0x936, 0xe3a, 0xf33, 0xc39, 0xd30,
                                0x3a0, 0x2a9, 0x1a3, 0xaa , 0x7a6, 0x6af, 0x5a5, 0x4ac,
                                0xbac, 0xaa5, 0x9af, 0x8a6, 0xfaa, 0xea3, 0xda9, 0xca0,
                                0x460, 0x569, 0x663, 0x76a, 0x66 , 0x16f, 0x265, 0x36c,
                                0xc6c, 0xd65, 0xe6f, 0xf66, 0x86a, 0x963, 0xa69, 0xb60,
                                0x5f0, 0x4f9, 0x7f3, 0x6fa, 0x1f6, 0xff , 0x3f5, 0x2fc,
                                0xdfc, 0xcf5, 0xfff, 0xef6, 0x9fa, 0x8f3, 0xbf9, 0xaf0,
                                0x650, 0x759, 0x453, 0x55a, 0x256, 0x35f, 0x55 , 0x15c,
                                0xe5c, 0xf55, 0xc5f, 0xd56, 0xa5a, 0xb53, 0x859, 0x950,
                                0x7c0, 0x6c9, 0x5c3, 0x4ca, 0x3c6, 0x2cf, 0x1c5, 0xcc ,
                                0xfcc, 0xec5, 0xdcf, 0xcc6, 0xbca, 0xac3, 0x9c9, 0x8c0,
                                0x8c0, 0x9c9, 0xac3, 0xbca, 0xcc6, 0xdcf, 0xec5, 0xfcc,
                                0xcc , 0x1c5, 0x2cf, 0x3c6, 0x4ca, 0x5c3, 0x6c9, 0x7c0,
                                0x950, 0x859, 0xb53, 0xa5a, 0xd56, 0xc5f, 0xf55, 0xe5c,
                                0x15c, 0x55 , 0x35f, 0x256, 0x55a, 0x453, 0x759, 0x650,
                                0xaf0, 0xbf9, 0x8f3, 0x9fa, 0xef6, 0xfff, 0xcf5, 0xdfc,
                                0x2fc, 0x3f5, 0xff , 0x1f6, 0x6fa, 0x7f3, 0x4f9, 0x5f0,
                                0xb60, 0xa69, 0x963, 0x86a, 0xf66, 0xe6f, 0xd65, 0xc6c,
                                0x36c, 0x265, 0x16f, 0x66 , 0x76a, 0x663, 0x569, 0x460,
                                0xca0, 0xda9, 0xea3, 0xfaa, 0x8a6, 0x9af, 0xaa5, 0xbac,
                                0x4ac, 0x5a5, 0x6af, 0x7a6, 0xaa , 0x1a3, 0x2a9, 0x3a0,
                                0xd30, 0xc39, 0xf33, 0xe3a, 0x936, 0x83f, 0xb35, 0xa3c,
                                0x53c, 0x435, 0x73f, 0x636, 0x13a, 0x33 , 0x339, 0x230,
                                0xe90, 0xf99, 0xc93, 0xd9a, 0xa96, 0xb9f, 0x895, 0x99c,
                                0x69c, 0x795, 0x49f, 0x596, 0x29a, 0x393, 0x99 , 0x190,
                                0xf00, 0xe09, 0xd03, 0xc0a, 0xb06, 0xa0f, 0x905, 0x80c,
                                0x70c, 0x605, 0x50f, 0x406, 0x30a, 0x203, 0x109, 0x0]


cdef int tritable[256][16]
    
tritable[0][:] = [-1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1]
tritable[1][:] = [0, 8, 3, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1]
tritable[2][:] = [0, 1, 9, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1]
tritable[3][:] = [1, 8, 3, 9, 8, 1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1]
tritable[4][:] = [1, 2, 10, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1]
tritable[5][:] = [0, 8, 3, 1, 2, 10, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1]
tritable[6][:] = [9, 2, 10, 0, 2, 9, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1]
tritable[7][:] = [2, 8, 3, 2, 10, 8, 10, 9, 8, -1, -1, -1, -1, -1, -1, -1]
tritable[8][:] = [3, 11, 2, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1]
tritable[9][:] = [0, 11, 2, 8, 11, 0, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1]
tritable[10][:] = [1, 9, 0, 2, 3, 11, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1]
tritable[11][:] = [1, 11, 2, 1, 9, 11, 9, 8, 11, -1, -1, -1, -1, -1, -1, -1]
tritable[12][:] = [3, 10, 1, 11, 10, 3, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1]
tritable[13][:] = [0, 10, 1, 0, 8, 10, 8, 11, 10, -1, -1, -1, -1, -1, -1, -1]
tritable[14][:] = [3, 9, 0, 3, 11, 9, 11, 10, 9, -1, -1, -1, -1, -1, -1, -1]
tritable[15][:] = [9, 8, 10, 10, 8, 11, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1]
tritable[16][:] = [4, 7, 8, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1]
tritable[17][:] = [4, 3, 0, 7, 3, 4, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1]
tritable[18][:] = [0, 1, 9, 8, 4, 7, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1]
tritable[19][:] = [4, 1, 9, 4, 7, 1, 7, 3, 1, -1, -1, -1, -1, -1, -1, -1]
tritable[20][:] = [1, 2, 10, 8, 4, 7, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1]
tritable[21][:] = [3, 4, 7, 3, 0, 4, 1, 2, 10, -1, -1, -1, -1, -1, -1, -1]
tritable[22][:] = [9, 2, 10, 9, 0, 2, 8, 4, 7, -1, -1, -1, -1, -1, -1, -1]
tritable[23][:] = [2, 10, 9, 2, 9, 7, 2, 7, 3, 7, 9, 4, -1, -1, -1, -1]
tritable[24][:] = [8, 4, 7, 3, 11, 2, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1]
tritable[25][:] = [11, 4, 7, 11, 2, 4, 2, 0, 4, -1, -1, -1, -1, -1, -1, -1]
tritable[26][:] = [9, 0, 1, 8, 4, 7, 2, 3, 11, -1, -1, -1, -1, -1, -1, -1]
tritable[27][:] = [4, 7, 11, 9, 4, 11, 9, 11, 2, 9, 2, 1, -1, -1, -1, -1]
tritable[28][:] = [3, 10, 1, 3, 11, 10, 7, 8, 4, -1, -1, -1, -1, -1, -1, -1]
tritable[29][:] = [1, 11, 10, 1, 4, 11, 1, 0, 4, 7, 11, 4, -1, -1, -1, -1]
tritable[30][:] = [4, 7, 8, 9, 0, 11, 9, 11, 10, 11, 0, 3, -1, -1, -1, -1]
tritable[31][:] = [4, 7, 11, 4, 11, 9, 9, 11, 10, -1, -1, -1, -1, -1, -1, -1]
tritable[32][:] = [9, 5, 4, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1]
tritable[33][:] = [9, 5, 4, 0, 8, 3, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1]
tritable[34][:] = [0, 5, 4, 1, 5, 0, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1]
tritable[35][:] = [8, 5, 4, 8, 3, 5, 3, 1, 5, -1, -1, -1, -1, -1, -1, -1]
tritable[36][:] = [1, 2, 10, 9, 5, 4, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1]
tritable[37][:] = [3, 0, 8, 1, 2, 10, 4, 9, 5, -1, -1, -1, -1, -1, -1, -1]
tritable[38][:] = [5, 2, 10, 5, 4, 2, 4, 0, 2, -1, -1, -1, -1, -1, -1, -1]
tritable[39][:] = [2, 10, 5, 3, 2, 5, 3, 5, 4, 3, 4, 8, -1, -1, -1, -1]
tritable[40][:] = [9, 5, 4, 2, 3, 11, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1]
tritable[41][:] = [0, 11, 2, 0, 8, 11, 4, 9, 5, -1, -1, -1, -1, -1, -1, -1]
tritable[42][:] = [0, 5, 4, 0, 1, 5, 2, 3, 11, -1, -1, -1, -1, -1, -1, -1]
tritable[43][:] = [2, 1, 5, 2, 5, 8, 2, 8, 11, 4, 8, 5, -1, -1, -1, -1]
tritable[44][:] = [10, 3, 11, 10, 1, 3, 9, 5, 4, -1, -1, -1, -1, -1, -1, -1]
tritable[45][:] = [4, 9, 5, 0, 8, 1, 8, 10, 1, 8, 11, 10, -1, -1, -1, -1]
tritable[46][:] = [5, 4, 0, 5, 0, 11, 5, 11, 10, 11, 0, 3, -1, -1, -1, -1]
tritable[47][:] = [5, 4, 8, 5, 8, 10, 10, 8, 11, -1, -1, -1, -1, -1, -1, -1]
tritable[48][:] = [9, 7, 8, 5, 7, 9, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1]
tritable[49][:] = [9, 3, 0, 9, 5, 3, 5, 7, 3, -1, -1, -1, -1, -1, -1, -1]
tritable[50][:] = [0, 7, 8, 0, 1, 7, 1, 5, 7, -1, -1, -1, -1, -1, -1, -1]
tritable[51][:] = [1, 5, 3, 3, 5, 7, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1]
tritable[52][:] = [9, 7, 8, 9, 5, 7, 10, 1, 2, -1, -1, -1, -1, -1, -1, -1]
tritable[53][:] = [10, 1, 2, 9, 5, 0, 5, 3, 0, 5, 7, 3, -1, -1, -1, -1]
tritable[54][:] = [8, 0, 2, 8, 2, 5, 8, 5, 7, 10, 5, 2, -1, -1, -1, -1]
tritable[55][:] = [2, 10, 5, 2, 5, 3, 3, 5, 7, -1, -1, -1, -1, -1, -1, -1]
tritable[56][:] = [7, 9, 5, 7, 8, 9, 3, 11, 2, -1, -1, -1, -1, -1, -1, -1]
tritable[57][:] = [9, 5, 7, 9, 7, 2, 9, 2, 0, 2, 7, 11, -1, -1, -1, -1]
tritable[58][:] = [2, 3, 11, 0, 1, 8, 1, 7, 8, 1, 5, 7, -1, -1, -1, -1]
tritable[59][:] = [11, 2, 1, 11, 1, 7, 7, 1, 5, -1, -1, -1, -1, -1, -1, -1]
tritable[60][:] = [9, 5, 8, 8, 5, 7, 10, 1, 3, 10, 3, 11, -1, -1, -1, -1]
tritable[61][:] = [5, 7, 0, 5, 0, 9, 7, 11, 0, 1, 0, 10, 11, 10, 0, -1]
tritable[62][:] = [11, 10, 0, 11, 0, 3, 10, 5, 0, 8, 0, 7, 5, 7, 0, -1]
tritable[63][:] = [11, 10, 5, 7, 11, 5, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1]
tritable[64][:] = [10, 6, 5, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1]
tritable[65][:] = [0, 8, 3, 5, 10, 6, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1]
tritable[66][:] = [9, 0, 1, 5, 10, 6, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1]
tritable[67][:] = [1, 8, 3, 1, 9, 8, 5, 10, 6, -1, -1, -1, -1, -1, -1, -1]
tritable[68][:] = [1, 6, 5, 2, 6, 1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1]
tritable[69][:] = [1, 6, 5, 1, 2, 6, 3, 0, 8, -1, -1, -1, -1, -1, -1, -1]
tritable[70][:] = [9, 6, 5, 9, 0, 6, 0, 2, 6, -1, -1, -1, -1, -1, -1, -1]
tritable[71][:] = [5, 9, 8, 5, 8, 2, 5, 2, 6, 3, 2, 8, -1, -1, -1, -1]
tritable[72][:] = [2, 3, 11, 10, 6, 5, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1]
tritable[73][:] = [11, 0, 8, 11, 2, 0, 10, 6, 5, -1, -1, -1, -1, -1, -1, -1]
tritable[74][:] = [0, 1, 9, 2, 3, 11, 5, 10, 6, -1, -1, -1, -1, -1, -1, -1]
tritable[75][:] = [5, 10, 6, 1, 9, 2, 9, 11, 2, 9, 8, 11, -1, -1, -1, -1]
tritable[76][:] = [6, 3, 11, 6, 5, 3, 5, 1, 3, -1, -1, -1, -1, -1, -1, -1]
tritable[77][:] = [0, 8, 11, 0, 11, 5, 0, 5, 1, 5, 11, 6, -1, -1, -1, -1]
tritable[78][:] = [3, 11, 6, 0, 3, 6, 0, 6, 5, 0, 5, 9, -1, -1, -1, -1]
tritable[79][:] = [6, 5, 9, 6, 9, 11, 11, 9, 8, -1, -1, -1, -1, -1, -1, -1]
tritable[80][:] = [5, 10, 6, 4, 7, 8, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1]
tritable[81][:] = [4, 3, 0, 4, 7, 3, 6, 5, 10, -1, -1, -1, -1, -1, -1, -1]
tritable[82][:] = [1, 9, 0, 5, 10, 6, 8, 4, 7, -1, -1, -1, -1, -1, -1, -1]
tritable[83][:] = [10, 6, 5, 1, 9, 7, 1, 7, 3, 7, 9, 4, -1, -1, -1, -1]
tritable[84][:] = [6, 1, 2, 6, 5, 1, 4, 7, 8, -1, -1, -1, -1, -1, -1, -1]
tritable[85][:] = [1, 2, 5, 5, 2, 6, 3, 0, 4, 3, 4, 7, -1, -1, -1, -1]
tritable[86][:] = [8, 4, 7, 9, 0, 5, 0, 6, 5, 0, 2, 6, -1, -1, -1, -1]
tritable[87][:] = [7, 3, 9, 7, 9, 4, 3, 2, 9, 5, 9, 6, 2, 6, 9, -1]
tritable[88][:] = [3, 11, 2, 7, 8, 4, 10, 6, 5, -1, -1, -1, -1, -1, -1, -1]
tritable[89][:] = [5, 10, 6, 4, 7, 2, 4, 2, 0, 2, 7, 11, -1, -1, -1, -1]
tritable[90][:] = [0, 1, 9, 4, 7, 8, 2, 3, 11, 5, 10, 6, -1, -1, -1, -1]
tritable[91][:] = [9, 2, 1, 9, 11, 2, 9, 4, 11, 7, 11, 4, 5, 10, 6, -1]
tritable[92][:] = [8, 4, 7, 3, 11, 5, 3, 5, 1, 5, 11, 6, -1, -1, -1, -1]
tritable[93][:] = [5, 1, 11, 5, 11, 6, 1, 0, 11, 7, 11, 4, 0, 4, 11, -1]
tritable[94][:] = [0, 5, 9, 0, 6, 5, 0, 3, 6, 11, 6, 3, 8, 4, 7, -1]
tritable[95][:] = [6, 5, 9, 6, 9, 11, 4, 7, 9, 7, 11, 9, -1, -1, -1, -1]
tritable[96][:] = [10, 4, 9, 6, 4, 10, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1]
tritable[97][:] = [4, 10, 6, 4, 9, 10, 0, 8, 3, -1, -1, -1, -1, -1, -1, -1]
tritable[98][:] = [10, 0, 1, 10, 6, 0, 6, 4, 0, -1, -1, -1, -1, -1, -1, -1]
tritable[99][:] = [8, 3, 1, 8, 1, 6, 8, 6, 4, 6, 1, 10, -1, -1, -1, -1]
tritable[100][:] = [1, 4, 9, 1, 2, 4, 2, 6, 4, -1, -1, -1, -1, -1, -1, -1]
tritable[101][:] = [3, 0, 8, 1, 2, 9, 2, 4, 9, 2, 6, 4, -1, -1, -1, -1]
tritable[102][:] = [0, 2, 4, 4, 2, 6, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1]
tritable[103][:] = [8, 3, 2, 8, 2, 4, 4, 2, 6, -1, -1, -1, -1, -1, -1, -1]
tritable[104][:] = [10, 4, 9, 10, 6, 4, 11, 2, 3, -1, -1, -1, -1, -1, -1, -1]
tritable[105][:] = [0, 8, 2, 2, 8, 11, 4, 9, 10, 4, 10, 6, -1, -1, -1, -1]
tritable[106][:] = [3, 11, 2, 0, 1, 6, 0, 6, 4, 6, 1, 10, -1, -1, -1, -1]
tritable[107][:] = [6, 4, 1, 6, 1, 10, 4, 8, 1, 2, 1, 11, 8, 11, 1, -1]
tritable[108][:] = [9, 6, 4, 9, 3, 6, 9, 1, 3, 11, 6, 3, -1, -1, -1, -1]
tritable[109][:] = [8, 11, 1, 8, 1, 0, 11, 6, 1, 9, 1, 4, 6, 4, 1, -1]
tritable[110][:] = [3, 11, 6, 3, 6, 0, 0, 6, 4, -1, -1, -1, -1, -1, -1, -1]
tritable[111][:] = [6, 4, 8, 11, 6, 8, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1]
tritable[112][:] = [7, 10, 6, 7, 8, 10, 8, 9, 10, -1, -1, -1, -1, -1, -1, -1]
tritable[113][:] = [0, 7, 3, 0, 10, 7, 0, 9, 10, 6, 7, 10, -1, -1, -1, -1]
tritable[114][:] = [10, 6, 7, 1, 10, 7, 1, 7, 8, 1, 8, 0, -1, -1, -1, -1]
tritable[115][:] = [10, 6, 7, 10, 7, 1, 1, 7, 3, -1, -1, -1, -1, -1, -1, -1]
tritable[116][:] = [1, 2, 6, 1, 6, 8, 1, 8, 9, 8, 6, 7, -1, -1, -1, -1]
tritable[117][:] = [2, 6, 9, 2, 9, 1, 6, 7, 9, 0, 9, 3, 7, 3, 9, -1]
tritable[118][:] = [7, 8, 0, 7, 0, 6, 6, 0, 2, -1, -1, -1, -1, -1, -1, -1]
tritable[119][:] = [7, 3, 2, 6, 7, 2, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1]
tritable[120][:] = [2, 3, 11, 10, 6, 8, 10, 8, 9, 8, 6, 7, -1, -1, -1, -1]
tritable[121][:] = [2, 0, 7, 2, 7, 11, 0, 9, 7, 6, 7, 10, 9, 10, 7, -1]
tritable[122][:] = [1, 8, 0, 1, 7, 8, 1, 10, 7, 6, 7, 10, 2, 3, 11, -1]
tritable[123][:] = [11, 2, 1, 11, 1, 7, 10, 6, 1, 6, 7, 1, -1, -1, -1, -1]
tritable[124][:] = [8, 9, 6, 8, 6, 7, 9, 1, 6, 11, 6, 3, 1, 3, 6, -1]
tritable[125][:] = [0, 9, 1, 11, 6, 7, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1]
tritable[126][:] = [7, 8, 0, 7, 0, 6, 3, 11, 0, 11, 6, 0, -1, -1, -1, -1]
tritable[127][:] = [7, 11, 6, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1]
tritable[128][:] = [7, 6, 11, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1]
tritable[129][:] = [3, 0, 8, 11, 7, 6, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1]
tritable[130][:] = [0, 1, 9, 11, 7, 6, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1]
tritable[131][:] = [8, 1, 9, 8, 3, 1, 11, 7, 6, -1, -1, -1, -1, -1, -1, -1]
tritable[132][:] = [10, 1, 2, 6, 11, 7, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1]
tritable[133][:] = [1, 2, 10, 3, 0, 8, 6, 11, 7, -1, -1, -1, -1, -1, -1, -1]
tritable[134][:] = [2, 9, 0, 2, 10, 9, 6, 11, 7, -1, -1, -1, -1, -1, -1, -1]
tritable[135][:] = [6, 11, 7, 2, 10, 3, 10, 8, 3, 10, 9, 8, -1, -1, -1, -1]
tritable[136][:] = [7, 2, 3, 6, 2, 7, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1]
tritable[137][:] = [7, 0, 8, 7, 6, 0, 6, 2, 0, -1, -1, -1, -1, -1, -1, -1]
tritable[138][:] = [2, 7, 6, 2, 3, 7, 0, 1, 9, -1, -1, -1, -1, -1, -1, -1]
tritable[139][:] = [1, 6, 2, 1, 8, 6, 1, 9, 8, 8, 7, 6, -1, -1, -1, -1]
tritable[140][:] = [10, 7, 6, 10, 1, 7, 1, 3, 7, -1, -1, -1, -1, -1, -1, -1]
tritable[141][:] = [10, 7, 6, 1, 7, 10, 1, 8, 7, 1, 0, 8, -1, -1, -1, -1]
tritable[142][:] = [0, 3, 7, 0, 7, 10, 0, 10, 9, 6, 10, 7, -1, -1, -1, -1]
tritable[143][:] = [7, 6, 10, 7, 10, 8, 8, 10, 9, -1, -1, -1, -1, -1, -1, -1]
tritable[144][:] = [6, 8, 4, 11, 8, 6, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1]
tritable[145][:] = [3, 6, 11, 3, 0, 6, 0, 4, 6, -1, -1, -1, -1, -1, -1, -1]
tritable[146][:] = [8, 6, 11, 8, 4, 6, 9, 0, 1, -1, -1, -1, -1, -1, -1, -1]
tritable[147][:] = [9, 4, 6, 9, 6, 3, 9, 3, 1, 11, 3, 6, -1, -1, -1, -1]
tritable[148][:] = [6, 8, 4, 6, 11, 8, 2, 10, 1, -1, -1, -1, -1, -1, -1, -1]
tritable[149][:] = [1, 2, 10, 3, 0, 11, 0, 6, 11, 0, 4, 6, -1, -1, -1, -1]
tritable[150][:] = [4, 11, 8, 4, 6, 11, 0, 2, 9, 2, 10, 9, -1, -1, -1, -1]
tritable[151][:] = [10, 9, 3, 10, 3, 2, 9, 4, 3, 11, 3, 6, 4, 6, 3, -1]
tritable[152][:] = [8, 2, 3, 8, 4, 2, 4, 6, 2, -1, -1, -1, -1, -1, -1, -1]
tritable[153][:] = [0, 4, 2, 4, 6, 2, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1]
tritable[154][:] = [1, 9, 0, 2, 3, 4, 2, 4, 6, 4, 3, 8, -1, -1, -1, -1]
tritable[155][:] = [1, 9, 4, 1, 4, 2, 2, 4, 6, -1, -1, -1, -1, -1, -1, -1]
tritable[156][:] = [8, 1, 3, 8, 6, 1, 8, 4, 6, 6, 10, 1, -1, -1, -1, -1]
tritable[157][:] = [10, 1, 0, 10, 0, 6, 6, 0, 4, -1, -1, -1, -1, -1, -1, -1]
tritable[158][:] = [4, 6, 3, 4, 3, 8, 6, 10, 3, 0, 3, 9, 10, 9, 3, -1]
tritable[159][:] = [10, 9, 4, 6, 10, 4, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1]
tritable[160][:] = [4, 9, 5, 7, 6, 11, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1]
tritable[161][:] = [0, 8, 3, 4, 9, 5, 11, 7, 6, -1, -1, -1, -1, -1, -1, -1]
tritable[162][:] = [5, 0, 1, 5, 4, 0, 7, 6, 11, -1, -1, -1, -1, -1, -1, -1]
tritable[163][:] = [11, 7, 6, 8, 3, 4, 3, 5, 4, 3, 1, 5, -1, -1, -1, -1]
tritable[164][:] = [9, 5, 4, 10, 1, 2, 7, 6, 11, -1, -1, -1, -1, -1, -1, -1]
tritable[165][:] = [6, 11, 7, 1, 2, 10, 0, 8, 3, 4, 9, 5, -1, -1, -1, -1]
tritable[166][:] = [7, 6, 11, 5, 4, 10, 4, 2, 10, 4, 0, 2, -1, -1, -1, -1]
tritable[167][:] = [3, 4, 8, 3, 5, 4, 3, 2, 5, 10, 5, 2, 11, 7, 6, -1]
tritable[168][:] = [7, 2, 3, 7, 6, 2, 5, 4, 9, -1, -1, -1, -1, -1, -1, -1]
tritable[169][:] = [9, 5, 4, 0, 8, 6, 0, 6, 2, 6, 8, 7, -1, -1, -1, -1]
tritable[170][:] = [3, 6, 2, 3, 7, 6, 1, 5, 0, 5, 4, 0, -1, -1, -1, -1]
tritable[171][:] = [6, 2, 8, 6, 8, 7, 2, 1, 8, 4, 8, 5, 1, 5, 8, -1]
tritable[172][:] = [9, 5, 4, 10, 1, 6, 1, 7, 6, 1, 3, 7, -1, -1, -1, -1]
tritable[173][:] = [1, 6, 10, 1, 7, 6, 1, 0, 7, 8, 7, 0, 9, 5, 4, -1]
tritable[174][:] = [4, 0, 10, 4, 10, 5, 0, 3, 10, 6, 10, 7, 3, 7, 10, -1]
tritable[175][:] = [7, 6, 10, 7, 10, 8, 5, 4, 10, 4, 8, 10, -1, -1, -1, -1]
tritable[176][:] = [6, 9, 5, 6, 11, 9, 11, 8, 9, -1, -1, -1, -1, -1, -1, -1]
tritable[177][:] = [3, 6, 11, 0, 6, 3, 0, 5, 6, 0, 9, 5, -1, -1, -1, -1]
tritable[178][:] = [0, 11, 8, 0, 5, 11, 0, 1, 5, 5, 6, 11, -1, -1, -1, -1]
tritable[179][:] = [6, 11, 3, 6, 3, 5, 5, 3, 1, -1, -1, -1, -1, -1, -1, -1]
tritable[180][:] = [1, 2, 10, 9, 5, 11, 9, 11, 8, 11, 5, 6, -1, -1, -1, -1]
tritable[181][:] = [0, 11, 3, 0, 6, 11, 0, 9, 6, 5, 6, 9, 1, 2, 10, -1]
tritable[182][:] = [11, 8, 5, 11, 5, 6, 8, 0, 5, 10, 5, 2, 0, 2, 5, -1]
tritable[183][:] = [6, 11, 3, 6, 3, 5, 2, 10, 3, 10, 5, 3, -1, -1, -1, -1]
tritable[184][:] = [5, 8, 9, 5, 2, 8, 5, 6, 2, 3, 8, 2, -1, -1, -1, -1]
tritable[185][:] = [9, 5, 6, 9, 6, 0, 0, 6, 2, -1, -1, -1, -1, -1, -1, -1]
tritable[186][:] = [1, 5, 8, 1, 8, 0, 5, 6, 8, 3, 8, 2, 6, 2, 8, -1]
tritable[187][:] = [1, 5, 6, 2, 1, 6, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1]
tritable[188][:] = [1, 3, 6, 1, 6, 10, 3, 8, 6, 5, 6, 9, 8, 9, 6, -1]
tritable[189][:] = [10, 1, 0, 10, 0, 6, 9, 5, 0, 5, 6, 0, -1, -1, -1, -1]
tritable[190][:] = [0, 3, 8, 5, 6, 10, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1]
tritable[191][:] = [10, 5, 6, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1]
tritable[192][:] = [11, 5, 10, 7, 5, 11, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1]
tritable[193][:] = [11, 5, 10, 11, 7, 5, 8, 3, 0, -1, -1, -1, -1, -1, -1, -1]
tritable[194][:] = [5, 11, 7, 5, 10, 11, 1, 9, 0, -1, -1, -1, -1, -1, -1, -1]
tritable[195][:] = [10, 7, 5, 10, 11, 7, 9, 8, 1, 8, 3, 1, -1, -1, -1, -1]
tritable[196][:] = [11, 1, 2, 11, 7, 1, 7, 5, 1, -1, -1, -1, -1, -1, -1, -1]
tritable[197][:] = [0, 8, 3, 1, 2, 7, 1, 7, 5, 7, 2, 11, -1, -1, -1, -1]
tritable[198][:] = [9, 7, 5, 9, 2, 7, 9, 0, 2, 2, 11, 7, -1, -1, -1, -1]
tritable[199][:] = [7, 5, 2, 7, 2, 11, 5, 9, 2, 3, 2, 8, 9, 8, 2, -1]
tritable[200][:] = [2, 5, 10, 2, 3, 5, 3, 7, 5, -1, -1, -1, -1, -1, -1, -1]
tritable[201][:] = [8, 2, 0, 8, 5, 2, 8, 7, 5, 10, 2, 5, -1, -1, -1, -1]
tritable[202][:] = [9, 0, 1, 5, 10, 3, 5, 3, 7, 3, 10, 2, -1, -1, -1, -1]
tritable[203][:] = [9, 8, 2, 9, 2, 1, 8, 7, 2, 10, 2, 5, 7, 5, 2, -1]
tritable[204][:] = [1, 3, 5, 3, 7, 5, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1]
tritable[205][:] = [0, 8, 7, 0, 7, 1, 1, 7, 5, -1, -1, -1, -1, -1, -1, -1]
tritable[206][:] = [9, 0, 3, 9, 3, 5, 5, 3, 7, -1, -1, -1, -1, -1, -1, -1]
tritable[207][:] = [9, 8, 7, 5, 9, 7, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1]
tritable[208][:] = [5, 8, 4, 5, 10, 8, 10, 11, 8, -1, -1, -1, -1, -1, -1, -1]
tritable[209][:] = [5, 0, 4, 5, 11, 0, 5, 10, 11, 11, 3, 0, -1, -1, -1, -1]
tritable[210][:] = [0, 1, 9, 8, 4, 10, 8, 10, 11, 10, 4, 5, -1, -1, -1, -1]
tritable[211][:] = [10, 11, 4, 10, 4, 5, 11, 3, 4, 9, 4, 1, 3, 1, 4, -1]
tritable[212][:] = [2, 5, 1, 2, 8, 5, 2, 11, 8, 4, 5, 8, -1, -1, -1, -1]
tritable[213][:] = [0, 4, 11, 0, 11, 3, 4, 5, 11, 2, 11, 1, 5, 1, 11, -1]
tritable[214][:] = [0, 2, 5, 0, 5, 9, 2, 11, 5, 4, 5, 8, 11, 8, 5, -1]
tritable[215][:] = [9, 4, 5, 2, 11, 3, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1]
tritable[216][:] = [2, 5, 10, 3, 5, 2, 3, 4, 5, 3, 8, 4, -1, -1, -1, -1]
tritable[217][:] = [5, 10, 2, 5, 2, 4, 4, 2, 0, -1, -1, -1, -1, -1, -1, -1]
tritable[218][:] = [3, 10, 2, 3, 5, 10, 3, 8, 5, 4, 5, 8, 0, 1, 9, -1]
tritable[219][:] = [5, 10, 2, 5, 2, 4, 1, 9, 2, 9, 4, 2, -1, -1, -1, -1]
tritable[220][:] = [8, 4, 5, 8, 5, 3, 3, 5, 1, -1, -1, -1, -1, -1, -1, -1]
tritable[221][:] = [0, 4, 5, 1, 0, 5, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1]
tritable[222][:] = [8, 4, 5, 8, 5, 3, 9, 0, 5, 0, 3, 5, -1, -1, -1, -1]
tritable[223][:] = [9, 4, 5, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1]
tritable[224][:] = [4, 11, 7, 4, 9, 11, 9, 10, 11, -1, -1, -1, -1, -1, -1, -1]
tritable[225][:] = [0, 8, 3, 4, 9, 7, 9, 11, 7, 9, 10, 11, -1, -1, -1, -1]
tritable[226][:] = [1, 10, 11, 1, 11, 4, 1, 4, 0, 7, 4, 11, -1, -1, -1, -1]
tritable[227][:] = [3, 1, 4, 3, 4, 8, 1, 10, 4, 7, 4, 11, 10, 11, 4, -1]
tritable[228][:] = [4, 11, 7, 9, 11, 4, 9, 2, 11, 9, 1, 2, -1, -1, -1, -1]
tritable[229][:] = [9, 7, 4, 9, 11, 7, 9, 1, 11, 2, 11, 1, 0, 8, 3, -1]
tritable[230][:] = [11, 7, 4, 11, 4, 2, 2, 4, 0, -1, -1, -1, -1, -1, -1, -1]
tritable[231][:] = [11, 7, 4, 11, 4, 2, 8, 3, 4, 3, 2, 4, -1, -1, -1, -1]
tritable[232][:] = [2, 9, 10, 2, 7, 9, 2, 3, 7, 7, 4, 9, -1, -1, -1, -1]
tritable[233][:] = [9, 10, 7, 9, 7, 4, 10, 2, 7, 8, 7, 0, 2, 0, 7, -1]
tritable[234][:] = [3, 7, 10, 3, 10, 2, 7, 4, 10, 1, 10, 0, 4, 0, 10, -1]
tritable[235][:] = [1, 10, 2, 8, 7, 4, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1]
tritable[236][:] = [4, 9, 1, 4, 1, 7, 7, 1, 3, -1, -1, -1, -1, -1, -1, -1]
tritable[237][:] = [4, 9, 1, 4, 1, 7, 0, 8, 1, 8, 7, 1, -1, -1, -1, -1]
tritable[238][:] = [4, 0, 3, 7, 4, 3, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1]
tritable[239][:] = [4, 8, 7, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1]
tritable[240][:] = [9, 10, 8, 10, 11, 8, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1]
tritable[241][:] = [3, 0, 9, 3, 9, 11, 11, 9, 10, -1, -1, -1, -1, -1, -1, -1]
tritable[242][:] = [0, 1, 10, 0, 10, 8, 8, 10, 11, -1, -1, -1, -1, -1, -1, -1]
tritable[243][:] = [3, 1, 10, 11, 3, 10, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1]
tritable[244][:] = [1, 2, 11, 1, 11, 9, 9, 11, 8, -1, -1, -1, -1, -1, -1, -1]
tritable[245][:] = [3, 0, 9, 3, 9, 11, 1, 2, 9, 2, 11, 9, -1, -1, -1, -1]
tritable[246][:] = [0, 2, 11, 8, 0, 11, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1]
tritable[247][:] = [3, 2, 11, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1]
tritable[248][:] = [2, 3, 8, 2, 8, 10, 10, 8, 9, -1, -1, -1, -1, -1, -1, -1]
tritable[249][:] = [9, 10, 2, 0, 9, 2, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1]
tritable[250][:] = [2, 3, 8, 2, 8, 10, 0, 1, 8, 1, 10, 8, -1, -1, -1, -1]
tritable[251][:] = [1, 10, 2, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1]
tritable[252][:] = [1, 3, 8, 9, 1, 8, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1]
tritable[253][:] = [0, 9, 1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1]
tritable[254][:] = [0, 3, 8, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1]
tritable[255][:] = [-1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1]
    

cdef void scalarfield(float **result,int index,Point pos,unsigned int *par,int parnum)nogil:
    #'''
    global cypar,cyparnum
    cdef int i = 0
    cdef int ii = 0
    cdef float dist = 0.0
    cdef float x = 0.0
    cdef float y = 0.0
    cdef float z = 0.0
    cdef float a = 1000000000.0
    cdef float b = 0
    cdef unsigned int bestid = 0
    #cdef Test *test = <Test *>malloc( parnum * cython.sizeof(Test) )
    #for i in range(parnum):
        #print "  ",par[i]
    for i in range(parnum):
        ii = par[i]
        x = pos.loc[0] - cypar[ii].loc[0]
        y = pos.loc[1] - cypar[ii].loc[1]
        z = pos.loc[2] - cypar[ii].loc[2]
        dist = x*x+y*y+z*z
        b = dist - (cypar[ii].size * cypar[ii].size)
        #test[i].id = ii
        #test[i].dist = b
        if b < a:
            a = b
            bestid = ii
    x = pos.loc[0] - cypar[bestid].loc[0]
    y = pos.loc[1] - cypar[bestid].loc[1]
    z = pos.loc[2] - cypar[bestid].loc[2]
    dist = (x*x+y*y+z*z)**0.5 - (cypar[bestid].size)
    result[index][0] = dist
    #quick_sort(test,parnum,distparam)
    #with gil:
       #print bestid,test[0].id,test[0].dist,test[1].dist
    '''   
    if parnum >= 4:
        for i in xrange(cypar[bestid].numprop):
            result[index][i+1] = (cypar[test[0].id].prop[i] * 0.75) + (cypar[test[1].id].prop[i] * 0.20) + (cypar[test[2].id].prop[i] * 0.04) + (cypar[test[3].id].prop[i] * 0.01)
    elif parnum >= 3:
        for i in xrange(cypar[bestid].numprop):
            result[index][i+1] = (cypar[test[0].id].prop[i] * 0.75) + (cypar[test[1].id].prop[i] * 0.20) + (cypar[test[2].id].prop[i] * 0.05)

    if parnum >= 2:
        for i in xrange(cypar[bestid].numprop):
            result[index][i+1] = (cypar[test[0].id].prop[i] * 0.75) + (cypar[test[1].id].prop[i] * 0.25)
    '''
    #else:        
    for i in xrange(cypar[bestid].numprop):
        result[index][i+1] = cypar[bestid].prop[i]

    #result[index][4] = (pos.loc[0]-cypar[bestid].loc[0]) + cypar[bestid].prop[3]
    #result[index][5] = (pos.loc[1]-cypar[bestid].loc[1]) + cypar[bestid].prop[4]
    #result[index][6] = (pos.loc[2]-cypar[bestid].loc[2]) + cypar[bestid].prop[5]
    return
    #'''
    '''        
    cdef float m = 2 #distance between spheres
    cdef float a
    cdef float b
    cdef float c
    cdef float csq
    a= 1.0/(1+(pos.loc[0]-m)*(pos.loc[0]-m)+pos.loc[1]*pos.loc[1]+pos.loc[2]*pos.loc[2])
    b= 1.0/(1+(pos.loc[0]+m)*(pos.loc[0]+m)+pos.loc[1]*pos.loc[1]+pos.loc[2]*pos.loc[2])
    c= 0.5*(sin(6*pos.loc[0])+sin(6*pos.loc[2]))
    csq=c**10
    return (a+b)-csq
    '''

    #return pos.loc[0]*pos.loc[0]+pos.loc[1]*pos.loc[1]+pos.loc[2]*pos.loc[2] 


cdef void polygonise(float **cycornervalues,int propnum,Point *cycornerpos,float isolevel,int blocknum)nogil:
    global edgetable,cytriangles,cytrimem,cytrinum
    
    
    cdef int i = 0
    cdef int ii = 0
    cdef int j = 0
    cdef int cubeindex = 0
    cdef Point *cyvertlist = NULL
    cdef float **cyvertprop = NULL
    #cornervalues = [0] * 8
    #cornerpos = [0] * 8
    #for i in range(8):
        #cornervalues[i] = cycornervalues[i]
        #cornerpos[i] = [cycornerpos[i][0],cycornerpos[i][1],cycornerpos[i][2]]

        #   Determine the index into the edge table which
        #   tells us which vertices are inside of the surface

    if cycornervalues[0][0] < isolevel: cubeindex = cubeindex | 1
    if cycornervalues[1][0] < isolevel: cubeindex = cubeindex | 2
    if cycornervalues[2][0] < isolevel: cubeindex = cubeindex | 4
    if cycornervalues[3][0] < isolevel: cubeindex = cubeindex | 8
    if cycornervalues[4][0] < isolevel: cubeindex = cubeindex | 16
    if cycornervalues[5][0] < isolevel: cubeindex = cubeindex | 32
    if cycornervalues[6][0] < isolevel: cubeindex = cubeindex | 64
    if cycornervalues[7][0] < isolevel: cubeindex = cubeindex | 128
    
    
    # Cube is entirely in/out of the surface
    if edgetable[cubeindex] == 0:
        return #[]

    #vertlist=[]
    cyvertlist = <Point *>malloc( 12 * cython.sizeof(Point) )
    cyvertprop = <float **>malloc( 12 * cython.sizeof(double) )
    
    for i in xrange(12):
        cyvertprop[i] = <float *>malloc( propnum * cython.sizeof(float) )
        for ii in xrange(propnum):
            cyvertprop[i][ii] = 666.777
    
        # Find the vertices where the surface intersects the cube
    if (edgetable[cubeindex] & 1):    vertexinterp(&cyvertlist[0],&cyvertprop[0][0],propnum,isolevel,cycornerpos[0],cycornerpos[1],cycornervalues[0][0],cycornervalues[1][0],&cycornervalues[0][1],&cycornervalues[1][1])
    if (edgetable[cubeindex] & 2):    vertexinterp(&cyvertlist[1],&cyvertprop[1][0],propnum,isolevel,cycornerpos[1],cycornerpos[2],cycornervalues[1][0],cycornervalues[2][0],&cycornervalues[1][1],&cycornervalues[2][1])
    if (edgetable[cubeindex] & 4):    vertexinterp(&cyvertlist[2],&cyvertprop[2][0],propnum,isolevel,cycornerpos[2],cycornerpos[3],cycornervalues[2][0],cycornervalues[3][0],&cycornervalues[2][1],&cycornervalues[3][1])
    if (edgetable[cubeindex] & 8):    vertexinterp(&cyvertlist[3],&cyvertprop[3][0],propnum,isolevel,cycornerpos[3],cycornerpos[0],cycornervalues[3][0],cycornervalues[0][0],&cycornervalues[3][1],&cycornervalues[0][1])
    if (edgetable[cubeindex] & 16):   vertexinterp(&cyvertlist[4],&cyvertprop[4][0],propnum,isolevel,cycornerpos[4],cycornerpos[5],cycornervalues[4][0],cycornervalues[5][0],&cycornervalues[4][1],&cycornervalues[5][1])
    if (edgetable[cubeindex] & 32):   vertexinterp(&cyvertlist[5],&cyvertprop[5][0],propnum,isolevel,cycornerpos[5],cycornerpos[6],cycornervalues[5][0],cycornervalues[6][0],&cycornervalues[5][1],&cycornervalues[6][1])
    if (edgetable[cubeindex] & 64):   vertexinterp(&cyvertlist[6],&cyvertprop[6][0],propnum,isolevel,cycornerpos[6],cycornerpos[7],cycornervalues[6][0],cycornervalues[7][0],&cycornervalues[6][1],&cycornervalues[7][1])
    if (edgetable[cubeindex] & 128):  vertexinterp(&cyvertlist[7],&cyvertprop[7][0],propnum,isolevel,cycornerpos[7],cycornerpos[4],cycornervalues[7][0],cycornervalues[4][0],&cycornervalues[7][1],&cycornervalues[4][1])
    if (edgetable[cubeindex] & 256):  vertexinterp(&cyvertlist[8],&cyvertprop[8][0],propnum,isolevel,cycornerpos[0],cycornerpos[4],cycornervalues[0][0],cycornervalues[4][0],&cycornervalues[0][1],&cycornervalues[4][1])
    if (edgetable[cubeindex] & 512):  vertexinterp(&cyvertlist[9],&cyvertprop[9][0],propnum,isolevel,cycornerpos[1],cycornerpos[5],cycornervalues[1][0],cycornervalues[5][0],&cycornervalues[1][1],&cycornervalues[5][1])
    if (edgetable[cubeindex] & 1024): vertexinterp(&cyvertlist[10],&cyvertprop[10][0],propnum,isolevel,cycornerpos[2],cycornerpos[6],cycornervalues[2][0],cycornervalues[6][0],&cycornervalues[2][1],&cycornervalues[6][1])
    if (edgetable[cubeindex] & 2048): vertexinterp(&cyvertlist[11],&cyvertprop[11][0],propnum,isolevel,cycornerpos[3],cycornerpos[7],cycornervalues[3][0],cycornervalues[7][0],&cycornervalues[3][1],&cycornervalues[7][1])
   
    #for i in xrange(12):
        #vertlist[i][0] = cyvertlist[i][0]
        #vertlist[i][1] = cyvertlist[i][1]
        #vertlist[i][2] = cyvertlist[i][2]

    #Create the triangle
    #triangles = []
    #for (i=0;triTable[cubeindex][i]!=-1;i+=3) {
    i=0
    #print blocknum
    #with gil:
        #print cyvertprop[0][0],propnum
    #with gil:
        #print "Polygonize1:",propnum
        
    while tritable[cubeindex][i] != -1:
        
        cytriangles[blocknum][cytrinum[blocknum]] = <float **>malloc( 3 * cython.sizeof(double) )
        
        for ii in range(3):
            cytriangles[blocknum][cytrinum[blocknum]][ii] = <float *>malloc((3 + propnum) * cython.sizeof(float) )
            
        cytriangles[blocknum][cytrinum[blocknum]][0][0] = cyvertlist[tritable[cubeindex][i]].loc[0]
        cytriangles[blocknum][cytrinum[blocknum]][0][1] = cyvertlist[tritable[cubeindex][i]].loc[1]
        cytriangles[blocknum][cytrinum[blocknum]][0][2] = cyvertlist[tritable[cubeindex][i]].loc[2]
        #with gil:
            #print ' Inside polygonise, inside tritable handling, cytriangles verts set for block triangle 0'
        for j in xrange(3,propnum+3):
            #if tritable[cubeindex][i] != -1:    
            cytriangles[blocknum][cytrinum[blocknum]][0][j] = cyvertprop[tritable[cubeindex][i]][j-3]
                #else:
            #    free(cyvertlist)
            #    cyvertlist = NULL
            #    for i in xrange(12):
            #        free(cyvertprop[i])
            #        cyvertprop[i] = NULL
            #    free(cyvertprop)
            #    cyvertprop = NULL
            #    return
            #    with gil:
            #        print 'i: ',i,' j: ',j,' blocknum: ',blocknum,' cubeindex: ', cubeindex
                
                #print(cytrinum[blocknum])
                
                #print(tritable[cubeindex][i])
            
        #with gil:
            #print ' Inside polygonise, inside tritable handling, cytriangles verts had something else done I do not understand'
        cytriangles[blocknum][cytrinum[blocknum]][1][0] = cyvertlist[tritable[cubeindex][i+1]].loc[0]
        cytriangles[blocknum][cytrinum[blocknum]][1][1] = cyvertlist[tritable[cubeindex][i+1]].loc[1]
        cytriangles[blocknum][cytrinum[blocknum]][1][2] = cyvertlist[tritable[cubeindex][i+1]].loc[2]
        #with gil:
            #print ' Inside polygonise, inside tritable handling, cytriangles verts set for block triangle 1'
        for j in xrange(3,propnum+3):
            cytriangles[blocknum][cytrinum[blocknum]][1][j] = cyvertprop[tritable[cubeindex][i+1]][j-3]
        #with gil:
            #print ' Inside polgyonise, same shit, whatever'
        cytriangles[blocknum][cytrinum[blocknum]][2][0] = cyvertlist[tritable[cubeindex][i+2]].loc[0]
        cytriangles[blocknum][cytrinum[blocknum]][2][1] = cyvertlist[tritable[cubeindex][i+2]].loc[1]
        cytriangles[blocknum][cytrinum[blocknum]][2][2] = cyvertlist[tritable[cubeindex][i+2]].loc[2]
        #with gil:
            #print ' Inside polygonise, inside tritable handling, cytriangles verts set for block triangle 2'
        for j in xrange(3,propnum+3):
            cytriangles[blocknum][cytrinum[blocknum]][2][j] = cyvertprop[tritable[cubeindex][i+2]][j-3]
        #with gil:
            #print ' Again with this shit'
        cytrinum[blocknum] += 1

        if cytrinum[blocknum] >= cytrimem[blocknum] - 2:
            cytrimem[blocknum] = <int>(<double>cytrimem[blocknum] * 1.25)
            cytriangles[blocknum] = <float ***>realloc(cytriangles[blocknum],cytrimem[blocknum] * cython.sizeof(double) )
        #with gil:
            #print ' Inside polygonise, inside tritable handling, cytriangles list has received vert locations'
        #triangles.append([vertlist[tritable[cubeindex][i  ]],vertlist[tritable[cubeindex][i+1]],vertlist[tritable[cubeindex][i+2]]])

        i+=3
    #with gil:
        #print ' Inside polygonise, finished processing cytriangles, free memory'
    free(cyvertlist)
    cyvertlist = NULL
    for i in xrange(12):
        free(cyvertprop[i])
        cyvertprop[i] = NULL
    free(cyvertprop)
    cyvertprop = NULL
    #with gil:
        #print ' inside polygonise, done with polygonising'
    #return #triangles

cdef void vertexinterp(Point *cyvertlist,float *cyvertprop,int propnum,float isolevel,Point p1,Point p2,float valp1,float valp2,float *prop1,float *prop2)nogil:
    cdef int i = 0
    #with gil:
        #print "VertexInterp1:",propnum

    if (fabs(isolevel-valp1) < 0.000001):
        cyvertlist.loc[0] = p1.loc[0]
        cyvertlist.loc[1] = p1.loc[1]
        cyvertlist.loc[2] = p1.loc[2]
        for i in xrange(propnum):
            #with gil:
                #print 666
            cyvertprop[i] = prop1[i]
        return
    if (fabs(isolevel-valp2) < 0.000001):
        cyvertlist.loc[0] = p2.loc[0]
        cyvertlist.loc[1] = p2.loc[1]
        cyvertlist.loc[2] = p2.loc[2]
        for i in xrange(propnum):
            #with gil:
                #print 777
            cyvertprop[i] = prop2[i]
        return
    if (fabs(valp1-valp2) < 0.000001):
        cyvertlist.loc[0] = p1.loc[0]
        cyvertlist.loc[1] = p1.loc[1]
        cyvertlist.loc[2] = p1.loc[2]
        for i in xrange(propnum):
            #with gil:
                #print 888
            cyvertprop[i] = prop1[i]
        return

    cdef float mu
    cdef float *p = [0,0,0]
    mu = ((isolevel - valp1) / (valp2 - valp1))
    cyvertlist.loc[0] = p1.loc[0] + mu * (p2.loc[0] - p1.loc[0])
    cyvertlist.loc[1] = p1.loc[1] + mu * (p2.loc[1] - p1.loc[1])
    cyvertlist.loc[2] = p1.loc[2] + mu * (p2.loc[2] - p1.loc[2])
    for i in xrange(propnum):
        cyvertprop[i] = prop1[i] + mu * (prop2[i] - prop1[i])
        #cyvertprop[i] = (prop1[i]*0.5) + (prop2[i]*0.5)
    #with gil:
        #print 999

    #return


cdef void arange(float *result,float start, float stop, float step)nogil:
    cdef float r = start
    cdef int icount = 0
    while r < stop:
        result[icount] = r
        r += step
        icount += 1
    #return

cdef void cellloop(Point *cyresult,float *p0,float *p1,float *r,int *cyres,int cellr)nogil:

    cdef float *xresult = NULL
    cdef float *yresult = NULL
    cdef float *zresult = NULL
    cdef int ix = 0
    cdef int iy = 0
    cdef int iz = 0
    cdef int i = 0
    xresult = <float *>malloc( (<int>(((p1[0] - p0[0]) / r[0]) + 1)) * cython.sizeof(float) )
    yresult = <float *>malloc( (<int>(((p1[1] - p0[1]) / r[1]) + 1)) * cython.sizeof(float) )
    zresult = <float *>malloc( (<int>(((p1[2] - p0[2]) / r[2]) + 1)) * cython.sizeof(float) )
    arange(&zresult[0],p0[2],p1[2],r[2])
    for iz in xrange(cyres[2]):
        arange(&yresult[0],p0[1],p1[1],r[1])
        for iy in xrange(cyres[1]):
            arange(&xresult[0],p0[0],p1[0],r[0])
            for ix in xrange(cyres[0]):
                cyresult[i].loc[0] = xresult[ix]
                cyresult[i].loc[1] = yresult[iy]
                cyresult[i].loc[2] = zresult[iz]
                i += 1

    free(xresult)
    free(yresult)
    free(zresult)
    xresult = NULL
    yresult = NULL
    zresult = NULL
    #return

cdef void cornerloop(Point *cyresult,float x,float y,float z)nogil:
    cdef int i = 0
    cdef int ii = 0
    cdef float *cx = [0,0,0,0]
    cdef float *cy = [0,0,0,0]
    cdef float *cz = [0,0]

    cz[0] = 0
    cz[1] = z
    for icz in xrange(2):
        cy[0] = 0
        cy[1] = y
        cy[2] = y
        cy[3] = 0
        cx[0] = 0
        cx[1] = 0
        cx[2] = x
        cx[3] = x
        for i in xrange(4):
            cyresult[ii].loc[0] = cx[i]
            cyresult[ii].loc[1] = cy[i]
            cyresult[ii].loc[2] = cz[icz]
            ii += 1
    #return

cpdef isosurface(float res,float isolevel,ploc,psize,pprop = -1,pzone = -1):
    global cytriangles,cytrimem,cytrinum,cypar,cyparnum,#cblock,#cblocknum,#cblockmem

    cdef long tri = 0
    cdef long vert = 0
    cdef long pt = 0
    cdef long prp = 0
    cdef long i = 0
    cdef long ii = 0
    cdef long j = 0
    cdef int ix = 0
    cdef int iy = 0
    cdef int iz = 0
    cdef float x = 0
    cdef float y = 0
    cdef float z = 0

    '''-------------------------------------
    from math import floor,ceil
    print('---')
    xmax = 148.19
    ymax = -12.33
    res = 0.3
    print('Original:',xmax,ymax)
    b = ceil(xmax/res)*res
    c = floor(ymax/res)*res
    print('Arondi:',b,c)
    print('Nombres',b/res,c/res)
    print('Distance',b - c , 'Resolution:',(b-c)/res)
    -----------------------------------------'''

    cdef float timer1 = 0
    cdef float timer2 = 0

    #timer2 = clock()
    cyparnum = len(psize)
    cypar = <Particle *>malloc( (cyparnum + 1) * cython.sizeof(Particle) )
    cdef unsigned int *cyparid = <unsigned int *>malloc( (cyparnum + 1) * cython.sizeof(int) )
    cdef unsigned int propnum = 0
    #print pprop
    if pprop == -1:
        for i in xrange(cyparnum):
            cyparid[i] = i
            cypar[i].id = i
            cypar[i].size = psize[i]
            cypar[i].loc[0] = ploc[i][0]
            cypar[i].loc[1] = ploc[i][1]
            cypar[i].loc[2] = ploc[i][2]
            cypar[i].prop = NULL
            cypar[i].numprop = 0
            #print i
    else:
        propnum = len(pprop[0])
        for i in xrange(cyparnum):
            cyparid[i] = i
            cypar[i].id = i
            cypar[i].size = psize[i]
            cypar[i].loc[0] = ploc[i][0]
            cypar[i].loc[1] = ploc[i][1]
            cypar[i].loc[2] = ploc[i][2]
            cypar[i].prop = <float *>malloc( (propnum) * cython.sizeof(float) )
            cypar[i].numprop = propnum
            for ii in xrange(cypar[i].numprop):
                cypar[i].prop[ii] = pprop[i][ii]
            #print i

    cdef float xmin = 10000000#FLT_MAX
    cdef float xmax = -10000000#FLT_MIN
    cdef float ymin = 10000000#FLT_MAX
    cdef float ymax = -10000000#FLT_MIN
    cdef float zmin = 10000000#FLT_MAX
    cdef float zmax = -10000000#FLT_MIN
    cdef float offset = 0
    if pzone == -1:
        for i in xrange(cyparnum):
            if cypar[i].loc[0] - cypar[i].size < xmin:
                xmin = cypar[i].loc[0] - cypar[i].size
            if cypar[i].loc[0] + cypar[i].size > xmax:
                xmax = cypar[i].loc[0] + cypar[i].size
            if cypar[i].loc[1] - cypar[i].size < ymin:
                ymin = cypar[i].loc[1] - cypar[i].size
            if cypar[i].loc[1] + cypar[i].size > ymax:
                ymax = cypar[i].loc[1] + cypar[i].size
            if cypar[i].loc[2] - cypar[i].size < zmin:
                zmin = cypar[i].loc[2] - cypar[i].size
            if cypar[i].loc[2] + cypar[i].size > zmax:
                zmax = cypar[i].loc[2] + cypar[i].size
        offset = res * 2.0
    else:
        xmin = pzone[0]
        xmax = pzone[1]
        ymin = pzone[2]
        ymax = pzone[3]
        zmin = pzone[4]
        zmax = pzone[5]
        offset = 0.0

    #print xmin,ymin,zmin
    #print xmax,ymax,zmax
    cdef float *cyp0 = [floor(xmin/res)*res,floor(ymin/res)*res,floor(zmin/res)*res]
    cdef float *cyp1 = [ceil(xmax/res)*res,ceil(ymax/res)*res,ceil(zmax/res)*res]
    cyp0[0] = cyp0[0] - (offset)
    cyp0[1] = cyp0[1] - (offset)
    cyp0[2] = cyp0[2] - (offset)
    cyp1[0] = cyp1[0] + (offset)
    cyp1[1] = cyp1[1] + (offset)
    cyp1[2] = cyp1[2] + (offset)
    cdef int *resolution = [<int>((cyp1[0]-cyp0[0])/res),<int>((cyp1[1]-cyp0[1])/res),<int>((cyp1[2]-cyp0[2])/res)]
    cdef int *cyres = [resolution[0],resolution[1],resolution[2]]
    cdef long cellr = <unsigned long>(resolution[0] * resolution[1] * resolution[2])

    print '  Voxel size:',res
    print '  Minimum BBox:',cyp0[0],cyp0[1],cyp0[2]
    print '  Maximum BBox:',cyp1[0],cyp1[1],cyp1[2]
    print '  3D Subdivisions:',cyres[0],cyres[1],cyres[2]
    
    #print '  RES:',(cyp1[0]-cyp0[0])/cyres[0],(cyp1[1]-cyp0[1])/cyres[1],(cyp1[2]-cyp0[2])/cyres[2]

    cdef int cblocknum = 0
    cdef int cblockmem = 0
    cdef Block *cblock = NULL
    cblocknum = 0
    cblockmem = 16
    cblock = <Block *>malloc( cblockmem * cython.sizeof(Block) )
    
    #print cyp0[0],cyp0[1],cyp0[2]
    #print cyp1[0],cyp1[1],cyp1[2]
    #print cyres[0],cyres[1],cyres[2]
    cdef int blocksize = 8
    SpacePartition(&cblock,&cblocknum,&cblockmem,&cypar[0],cyparnum,&cyparid[0],cyp0,cyp1,cyres,res,blocksize,0)
    
    cytrimem = <int *>malloc( cblocknum * cython.sizeof(int) )
    cytrinum = <int *>malloc( cblocknum * cython.sizeof(int) )
    cytriangles = <float ****>malloc( cblocknum * cython.sizeof(double) )
    
    for i in range(cblocknum):
        cytrimem[i] = 40
        cytrinum[i] = 0
        cytriangles[i] = <float ***>malloc( cytrimem[i] * cython.sizeof(double) )
        

    #timer2 = clock() - timer2
    #timer1 = clock()

    #print ' Get Particles:',timer2,'s'

    #print cblocknum,cblockmem

    #for i in range(cblocknum):
        #print 'loop',cblock[i].id,cblock[i].p0[0],cblock[i].p0[1],cblock[i].p0[2],'/',cblock[i].p1[0],cblock[i].p1[1],cblock[i].p1[2],'/',cblock[i].res[0],cblock[i].res[1],cblock[i].res[2]



    #build(cyp0,cyp1,cyres,cellr,isolevel,i)
    #print "Beginning:",propnum
    with nogil:
        for i in prange(cblocknum,schedule='dynamic',chunksize=1,num_threads=12):
            #build(cyp0,cyp1,cyres,cellr,isolevel,i)
            #build(cblock[i].p0,cblock[i].p1,cblock[i].res,cellr,isolevel,i)
            build2(&cblock[i].par[0],cblock[i].parnum,cblock[i].p0,cblock[i].p1,cblock[i].res,cellr,isolevel,i,res)
    
    #print '---'
    #for i in range(cblocknum):
        #print 'test2',cblock[i].id,cblock[i].p0[0],cblock[i].p0[1],cblock[i].p0[2],'/',cblock[i].p1[0],cblock[i].p1[1],cblock[i].p1[2],'/',cblock[i].res[0],cblock[i].res[1],cblock[i].res[2]
        #build(cblock[i].p0,cblock[i].p1,cblock[i].res,cellr,isolevel,i)
    #build(cyp0,cyp1,cyres,cellr,isolevel)

    #print ' calculate geometry:',clock() - timer1,'s'
    #timer1 = clock()

    totaltri = 0
    for i in range(cblocknum):
        totaltri += cytrinum[i]

    tmptriangles = [666.666] * totaltri * 3 * 3
    tmpprops = [666.666] * totaltri * 3 * propnum
    i = 0
    j = 0
    for ii in range(cblocknum):
        for tri in range(cytrinum[ii]):
            for vert in range(3):
                for pt in range(3):
                    tmptriangles[i] = cytriangles[ii][tri][vert][pt]
                    i += 1
                    #print i,cytrinum * 3 * 3
                for prp in range(3,propnum + 3):
                    tmpprops[j] = cytriangles[ii][tri][vert][prp]
                    #print(tmpprops[j])
                    j += 1
    #print(i,cytrinum * 3 * 3,cytrinum)
    #print(len(tmpprops),tmpprops[0:9])
    
    for ii in range(cblocknum):
        for tri in range(cytrinum[ii]):
            for i in range(3):
                free(cytriangles[ii][tri][i])
                cytriangles[ii][tri][i] = NULL
            free(cytriangles[ii][tri])
            cytriangles[ii][tri] = NULL
        free(cytriangles[ii])
        cytriangles[ii] = NULL
        free(cblock[ii].par)
        cblock[ii].par = NULL
    free(cytriangles)
    cytriangles = NULL
    free(cytrimem)
    cytrimem = NULL
    free(cytrinum)
    cytrinum = NULL
    for i in xrange(cyparnum):
        free(cypar[i].prop)
        cypar[i].prop = NULL
        cypar[i].numprop = 0
    free(cypar)
    cypar = NULL
    cyparnum = 0
    free(cblock)
    cblock = NULL
    cblockmem = 0
    cblocknum = 0
    print ' Testing isosurface finished'
    #print ' send to pyarray:',clock() - timer1,'s'
    return tmptriangles,tmpprops


cdef void SpacePartition(Block **cblock,int *cblocknum,int *cblockmem,Particle *cypar,int cyparnum,unsigned int *cyparid,float *cyp0,float *cyp1,int *cyres,float res,int size,int depth)nogil:
    global #cblock,#cblocknum,#cblockmem
    cdef int axis = depth % 3
    cdef int i = 0
    cdef int id = 0
    if cyres[0] <= size and cyres[1] <= size and cyres[2] <= size:
        if cyparnum <= 0:
            return
        #with gil:
        #    dir(cblocknum)
        #with gil:
        #print cblocknum[0],cblockmem[0]
        cblock[0][cblocknum[0]].id = cblocknum[0]
        #print 'fnc:',cblock[0][cblocknum[0]].id,cyp0[0],cyp0[1],cyp0[2],'/',cyp1[0],cyp1[1],cyp1[2],'/',cyres[0],cyres[1],cyres[2],'/',cyparnum
        #print 'mem adress before:',<long long>cblock[0]
        if cblocknum[0] >= cblockmem[0] - 2:
            #print 'num over mem'
            cblockmem[0] = <int>(<double>cblockmem[0] * 1.5)
            #print 'mem ajusted to', cblockmem[0]
            cblock[0] = <Block *>realloc(cblock[0], cblockmem[0] * cython.sizeof(Block))
            #print 'mem adress after:',<long long>cblock[0]
            #print 'realloc'
            #print cblock[0][5].id
            #print cblock[0][cblocknum[0]].id
        cblock[0][cblocknum[0]].p0[0] = cyp0[0]
        cblock[0][cblocknum[0]].p0[1] = cyp0[1]
        cblock[0][cblocknum[0]].p0[2] = cyp0[2]
        cblock[0][cblocknum[0]].p1[0] = cyp1[0]
        cblock[0][cblocknum[0]].p1[1] = cyp1[1]
        cblock[0][cblocknum[0]].p1[2] = cyp1[2]
        cblock[0][cblocknum[0]].res[0] = cyres[0]
        cblock[0][cblocknum[0]].res[1] = cyres[1]
        cblock[0][cblocknum[0]].res[2] = cyres[2]
        cblock[0][cblocknum[0]].parnum = cyparnum
        cblock[0][cblocknum[0]].par = <unsigned int*>malloc( cblock[0][cblocknum[0]].parnum * cython.sizeof(int) )
        #print cblock[0][cblocknum[0]].parnum

        for i in range(cblock[0][cblocknum[0]].parnum):
            #print cyparid[i]
            cblock[0][cblocknum[0]].par[i] = cyparid[i]

        #print '    >Out axis:',axis,'depth:',depth
        cblocknum[0] += 1
        
        return

    if cyres[axis] <= size:
        #with gil:
        #print '    >Axis ',[axis],' finish'
        #print cyparnum,cblocknum[0],cblockmem[0]
        SpacePartition(&cblock[0],&cblocknum[0],&cblockmem[0],&cypar[0],cyparnum,&cyparid[0],cyp0,cyp1,cyres,res,size,depth + 1)
        return

    cdef int m = cyres[axis] / 2
    cdef int *lcyres = [cyres[0],cyres[1],cyres[2]]
    cdef int *rcyres = [cyres[0],cyres[1],cyres[2]]
    lcyres[axis] = m
    rcyres[axis] = cyres[axis] - m
    cdef float *lcyp0 = [cyp0[0],cyp0[1],cyp0[2]]
    cdef float *lcyp1 = [cyp1[0],cyp1[1],cyp1[2]]
    lcyp1[axis] = lcyp0[axis] + (res * m)
    cdef float *rcyp0 = [cyp0[0],cyp0[1],cyp0[2]]
    cdef float *rcyp1 = [cyp1[0],cyp1[1],cyp1[2]]
    rcyp0[axis] = lcyp1[axis]
    #rcyp1[axis] = cyp1[axis]

    cdef unsigned int *parL = <unsigned int *>malloc( (cyparnum + 1) * cython.sizeof(int) )
    cdef int parnumL = 0
    cdef unsigned int *parR = <unsigned int *>malloc( (cyparnum + 1) * cython.sizeof(int) )
    cdef int parnumR = 0
    cdef float parsize = 0
    for i in range(cyparnum):
        id = cyparid[i]
        parsize = cypar[id].size + res
        #print cypar[id].size
        if cypar[id].loc[axis] <= lcyp1[axis] or (cypar[id].loc[axis] - parsize) <= lcyp1[axis]:
            #with gil:
                #print '    ',id,'axis:',axis,'p0:',lcyp0[axis],'p1:',lcyp1[axis],'par pos:',cypar[id].loc[axis],'par min:',cypar[id].loc[axis] - parsize,'par max:',cypar[id].loc[axis] + parsize
            parL[parnumL] = id
            parnumL += 1
        if cypar[id].loc[axis] >= rcyp0[axis] or (cypar[id].loc[axis] + parsize) >= rcyp0[axis]:
            parR[parnumR] = id
            parnumR += 1


    SpacePartition(&cblock[0],&cblocknum[0],&cblockmem[0],&cypar[0],parnumL,&parL[0],lcyp0,lcyp1,lcyres,res,size,depth + 1)

    SpacePartition(&cblock[0],&cblocknum[0],&cblockmem[0],&cypar[0],parnumR,&parR[0],rcyp0,rcyp1,rcyres,res,size,depth + 1)
    free(parL)
    parL = NULL
    free(parR)
    parR = NULL
    return

cdef void build2(unsigned int *cyparid,int cyparnum,float *cyp0,float *cyp1,int *cyres,long cellr,float isolevel,int blocknum,float res)nogil:
    global cytriangles,cytrimem,cytrinum,cypar
    
    cdef float x = 0.0
    cdef float y = 0.0
    cdef float z = 0.0
    cdef float cx = 0.0
    cdef float cy = 0.0
    cdef float cz = 0.0
    cdef int i = 0
    cdef int ii = 0
    cdef int cblocknum = 0
    cdef int cblockmem = 0
    cdef Block *cblock = NULL
    cblocknum = 0
    cblockmem = 16
    cblock = <Block *>malloc( cblockmem * cython.sizeof(Block) )
    cdef int blocksize = 1
    
    SpacePartition(&cblock,&cblocknum,&cblockmem,&cypar[0],cyparnum,&cyparid[0],cyp0,cyp1,cyres,res,blocksize,0)
    
    #SpacePartition(&cblock,&cblocknum,&cblockmem,&cypar[0],cyparnum,&cyparid[0],cyp0,cyp1,cyres,res,blocksize,0)
    cdef Point *cornerpos = NULL
    cdef Point *cornerl = NULL
    cornerpos = <Point *>malloc( 8 * cython.sizeof(Point) )
    cornerl = <Point *>malloc( 8 * cython.sizeof(Point) )

    cdef float **cornervalues = NULL
    cornervalues = <float **>malloc( 8 * cython.sizeof(double) )
    
    for i in xrange(8):
        cornervalues[i] = <float *>malloc( (cypar[0].numprop + 1) * cython.sizeof(float) )
        for ii in xrange(cypar[0].numprop + 1):
            cornervalues[i][ii] = 0.0
    
    #with gil:
        #print "Building:",cypar[0].numprop
    cdef float *r = [res,res,res]
    
    for i in range(cblocknum):
        x = cblock[i].p0[0]
        y = cblock[i].p0[1]
        z = cblock[i].p0[2]
        cornerloop(&cornerl[0],r[0],r[1],r[2])
        
        #with gil:
            #print 'i:',i,'  ',cblock[i].p0[0],cblock[i].p0[1],cblock[i].p0[2],'/',cblock[i].p1[0],cblock[i].p1[1],cblock[i].p1[2],' parnum:',cblock[i].parnum
        for ii in xrange(8):
            cx = cornerl[ii].loc[0]
            cy = cornerl[ii].loc[1]
            cz = cornerl[ii].loc[2]
            cornerpos[ii].loc[0] = x+cx
            cornerpos[ii].loc[1] = y+cy
            cornerpos[ii].loc[2] = z+cz
            scalarfield(&cornervalues[0],ii,cornerpos[ii],cblock[i].par,cblock[i].parnum)
            
        
        polygonise(&cornervalues[0],cypar[0].numprop,cornerpos,isolevel,blocknum)
        
    
    for i in range(cblocknum):
        free(cblock[i].par)
        cblock[i].par = NULL
    free(cblock)
    cblock = NULL
    free(cornerl)
    cornerl = NULL
    free(cornerpos)
    cornerpos = NULL
    for i in xrange(8):
        free(cornervalues[i])
        cornervalues[i] = NULL
    free(cornervalues)
    cornervalues = NULL
    

    return

"""    
cdef void build(float *cyp0,float *cyp1,int *cyres,long cellr,float isolevel,int blocknum)nogil:
    global cytriangles,cytrimem,cytrinum,cypar,cyparnum
    
    #cdef float *cyp0 = [p0[0],p0[1],p0[2]]
    #cdef float *cyp1 = [p1[0],p1[1],p1[2]]
    #cdef int *cyres = [resolution[0],resolution[1],resolution[2]]
    #cdef int cellr = <int>(resolution[0] * resolution[1] * resolution[2])
    
    cdef long i = 0
    cdef long ii = 0
    cdef long ix = 0
    cdef long iy = 0
    cdef long iz = 0
    cdef float x = 0
    cdef float y = 0
    cdef float z = 0
    cdef float cx = 0
    cdef float cy = 0
    cdef float cz = 0
    cdef float *r = [0,0,0]
    cdef float sx = 0
    cdef float sy = 0
    cdef float sz = 0
    cdef long tz = 0
    cdef long ty = 0
    cdef long tx = 0
    cdef float ttz = 0
    cdef float tty = 0
    cdef float ttx = 0
    cdef float xsize = 0
    cdef float ysize = 0
    cdef float zsize = 0
    cdef long xmin = 0
    cdef long xmax = 0
    cdef long ymin = 0
    cdef long ymax = 0
    cdef long zmin = 0
    cdef long zmax = 0
    cdef unsigned long id = 0
    cdef float timer1 = 0
    cdef float timer2 = 0
    cdef float timer3 = 0
    
    cdef Point *cornerpos = NULL
    cdef float *cornervalues = NULL
    cdef Point *celll = NULL
    cdef Point *cornerl = NULL
    
    
    cornerpos = <Point *>malloc( 8 * cython.sizeof(Point) )
    cornerl = <Point *>malloc( 8 * cython.sizeof(Point) )
    
    #celll = <Point *>malloc( cellr * cython.sizeof(Point) )
    
    cornervalues = <float *>malloc( 8 * cython.sizeof(float) )
    
    for i in range(3):
        r[i] = (cyp1[i]-cyp0[i])/cyres[i]

    #cellloop(&celll[0],cyp0,cyp1,r,cyres,cellr)
    
    #print 'ceil 2.25 = ', ceil(2.25)
    #print 'floor 2.25 = ', floor(2.25)
    
    ##with gil:
        #timer1 = clock()
    
    cdef unsigned int *parid = <unsigned int *>malloc( cyparnum * cython.sizeof(int) )
    #with gil:
        #print 'parnum:',cyparnum
    for i in range(cyparnum):
        parid[i] = cypar[i].id
        #with gil:
            #print 'par ID:',parid[i]
    
    for i in range(cellr):
        id = i
        #x = celll[i].loc[0]
        #y = celll[i].loc[1]
        #z = celll[i].loc[2]
        #'''
        sx = fabs((cyp1[0] - cyp0[0])) / cyres[0]
        sy = fabs((cyp1[1] - cyp0[1])) / cyres[1]
        sz = fabs((cyp1[2] - cyp0[2])) / cyres[2]
        tz = int(id/(cyres[1]*cyres[0]))  #(((int(i/(cyres[2]*cyres[2]))) * sz) + cyp0[2])
        ty = int((id-(tz*(cyres[1]*cyres[0])))/cyres[0])
        tx = int((id-(tz*(cyres[1]*cyres[0])))-(ty * cyres[0]))
        ttz = ((tz * sz) + cyp0[2])
        tty = ((ty * sy) + cyp0[1])
        ttx = ((tx * sx) + cyp0[0])
        x = ttx
        y = tty
        z = ttz
        #with gil:
            #print x,y,z
        #'''
        #print i,':',x,y,z," | ",tx,ty,tz," | ",ttx,tty,ttz
        cornerloop(&cornerl[0],r[0],r[1],r[2])
        for ii in xrange(8):
            cx = cornerl[ii].loc[0]
            cy = cornerl[ii].loc[1]
            cz = cornerl[ii].loc[2]
            cornerpos[ii].loc[0] = x+cx
            cornerpos[ii].loc[1] = y+cy
            cornerpos[ii].loc[2] = z+cz
            cornervalues[ii] = scalarfield(cornerpos[ii],&parid[0],cyparnum)
        polygonise(cornervalues,cornerpos,isolevel,blocknum)
    

    free(cornerl)
    cornerl = NULL
    free(cornerpos)
    cornerpos = NULL
    free(cornervalues)
    cornervalues = NULL
    #free(celll)
    #celll = NULL
    
    #with gil:
        #timer3 = clock() - timer3
    #with gil:
        #print "CPU No:",blocknum," cells:",ncellnum,"/",cellnum,' findvox:',timer1,'s  optivox:',timer2,'s  geo:',timer3,'s'
    
    return
"""

cdef float xparam(Point a)nogil:
    return a.loc[0]

cdef float yparam(Point a)nogil:
    return a.loc[1]

cdef float zparam(Point a)nogil:
    return a.loc[2]


cdef int idparam(Test a)nogil:
    return a.id

cdef float distparam(Test a)nogil:
    return a.dist


cdef void quick_sort(Test *a,long long n,f_type func)nogil:
    if (n < 2):
        return
    cdef Test t
    cdef double p = func(a[n / 2])#a[n / 2].loc[0]
    cdef Test *l = a
    cdef Test *r = a + n - 1
    while l <= r:
        if func(l[0]) < p:
            l += 1
            continue

        if func(r[0]) > p:
            r -= 1
            continue #// we need to check the condition (l <= r) every time we change the value of l or r

        t = l[0]
        l[0] = r[0]
        #l[0], r[0] = r[0], l[0]  # suggested by stephan to remove temp variable t but slower
        l += 1
        r[0] = t
        r -= 1

    quick_sort(a, r - a + 1,func)
    quick_sort(l, a + n - l,func)


cdef int bsearch(Point *A,int n, float x,char searchFirst)nogil:
    cdef int low = 0
    cdef int high = n-1
    cdef int result = -1
    cdef int mid = 0

    while low <= high:
        mid = (low+high)/2
        if A[mid].loc[0] == x:
            result = mid
            if searchFirst == 1:
                high = mid-1
            else:
                low = mid+1
        elif x < A[mid].loc[0]:
            high = mid-1
        else:
            low = mid+1
    return result


cdef int arraysearch(int element,Cell *array,int len)nogil:
    cdef int i = 0
    for i in xrange(len):
        if element == array[i].id:
            return i
    return -1

cdef struct Block:
    unsigned long id
    float p0[3]
    float p1[3]
    int res[3]
    unsigned int *par
    unsigned int parnum
    unsigned int parmem

cdef struct Point:
    unsigned long id
    float loc[3]

cdef struct Particle:
    unsigned long id
    float size
    float loc[3]
    float *prop
    unsigned int numprop

cdef struct Cell:
    unsigned long id
    unsigned int *par
    int parnum
    int parmem

cdef struct Test:
    unsigned long id
    float dist
