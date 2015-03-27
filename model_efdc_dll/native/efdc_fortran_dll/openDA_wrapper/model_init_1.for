
      SUBROUTINE model_init_1

C     First part of initialization before VARINIT is called
C     Original EFDC.INP [lines: 121-187]

      USE global
      USE model_extra_global

      IMPLICIT NONE

      IS_TIMING=.TRUE.   
      TIME_END=0.0  
      CALL CPU_TIME(TIME_START)

      CALL WELCOME  
C  
C **  OPEN OUTPUT FILES  
C  
      OPEN(7,FILE='EFDC.OUT',STATUS='UNKNOWN')  
      OPEN(8,FILE='EFDCLOG.OUT',STATUS='UNKNOWN')  
      OPEN(9,FILE='TIME.LOG',STATUS='UNKNOWN') 
      CLOSE(7,STATUS='DELETE')  
      CLOSE(8,STATUS='DELETE')  
      CLOSE(9,STATUS='DELETE')  
      OPEN(7,FILE='EFDC.OUT',STATUS='UNKNOWN')  
      write(7,*) 'Modified by GEOSR (NH007_20120418_fixedweir)' !GEOSR 2012. 4.18
      OPEN(8,FILE='EFDCLOG.OUT',STATUS='UNKNOWN')  
      OPEN(9,FILE='TIME.LOG',STATUS='UNKNOWN')  

      OPEN(1,FILE='DRYWET.LOG',STATUS='UNKNOWN') 
      CLOSE(1,STATUS='DELETE')  
      OPEN(1,FILE='VSFP.OUT',STATUS='UNKNOWN')  
      CLOSE(1,STATUS='DELETE')  
      OPEN(1,FILE='SEDIAG.OUT',STATUS='UNKNOWN')  
      CLOSE(1,STATUS='DELETE')  
      OPEN(1,FILE='CFL.OUT',STATUS='UNKNOWN')  
      CLOSE(1,STATUS='DELETE')  
      OPEN(1,FILE='NEGSEDSND.OUT',STATUS='UNKNOWN')  
      CLOSE(1,STATUS='DELETE')  
      OPEN(1,FILE='ERROR.LOG',STATUS='UNKNOWN')  
      CLOSE(1,STATUS='DELETE')

      END SUBROUTINE  model_init_1