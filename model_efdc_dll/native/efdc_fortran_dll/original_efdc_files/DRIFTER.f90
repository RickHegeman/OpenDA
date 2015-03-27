      MODULE DRIFTER
! *** DRIFTER.F90 IS A LAGRANGIAN PARTICLE TRACKING MODULE FOR THE DYNAMIC SOLUTIONS VERSION OF EFDC (I.E. EFDC_DS)
! *** THIS MODULE COMPLETELY REPLACES THE PREVIOUS VERSIONS OF PARTICLE TRACKING IN EFDC.  
! *** THE CARDS C67 AND C68 IN THE EFDC.INP FILE WERE LEFT INTACT TO PROVIDE COMPATIBILITY WITH
! *** OTHER VERSIONS OF EFDC.  

USE GLOBAL  

IMPLICIT NONE

      LOGICAL(4),PRIVATE::BEDGEMOVE
      REAL(RKD) ,PRIVATE::XLA1,YLA1,ZLA1
!REAL(RKD) ,POINTER,PRIVATE::ZCTR(:)
REAL,ALLOCATABLE,DIMENSION(:)::ZCTR

CONTAINS

SUBROUTINE DRIFTERC   ! ***************************************************************************
  ! SOLVE DIFFERENTIAL EQS. FOR (X,Y,Z):
  ! DX=U.DT+RAN.SQRT(2EH.DT)
  ! DY=V.DT+RAN.SQRT(2EH.DT)
  ! DZ=W.DT+RAN.SQRT(2EV.DT)
  ! U(L,K),V(L,K),W(L,K),K=1,KC,L=2:LA    CURRENT TIME
  ! U1(L,K),V1(L,K),W1(L,K),K=1,KC,L=2:LA PREVIOUS TIME
  ! N: TIME STEP
  INTEGER(4)::NP,VER
  REAL(RKD) ::KDX1,KDX2,KDX3,KDX4
  REAL(RKD) ::KDY1,KDY2,KDY3,KDY4
  REAL(RKD) ::KDZ1,KDZ2,KDZ3,KDZ4
  REAL(RKD) ::U1NP,V1NP,W1NP,U2NP,V2NP,W2NP
  REAL(RKD) ::ZSIG
  REAL, SAVE::TIMENEXT, PMC
  CHARACTER*80 TITLE,METHOD 

!{GEOSR, OIL, CWCHO, 101104 
  REAL R1, R2                                
  REAL(RKD) ::UOIL, VOIL, DIFFVEL, TRANSTIME
!}

  TITLE='PREDICTION OF TRAJECTORIES OF DRIFTERS'  

!{GEOSR, OIL, CWCHO, 101103
  IF (IDTOX>=4440) THEN                      
    METHOD='METHOD: EXPLICIT EULER WITH OIL'
!}	  
  ELSEIF (ISPD==2.AND.IDTOX<4440) THEN
    METHOD='METHOD: EXPLICIT EULER'
  ELSEIF(ISPD==3.AND.IDTOX<4440) THEN
    METHOD='METHOD: PRE-CORRECTOR EULER'
  ELSEIF(ISPD==4.AND.IDTOX<4440) THEN
    METHOD='METHOD: RUNGE-KUTTA 4'
  ENDIF
  
  !----------FIRST CALL--------------------
  IF(JSPD.EQ.1) THEN 
!{GEOSR, OIL, CWCHO, 101113
    if(.not.ALLOCATED(ZCTR)) ALLOCATE(ZCTR(0:KC+1))
!}	                   	
    CALL CONTAINER(XLA,YLA,ZLA,LLA,KLA)      !OUT:LLA,KLA,BELVLA,HPLA

!{GEOSR, OIL, CWCHO, 101112
  IF (IDTOX>=4440) THEN 
	CALL OUTOIL
  ENDIF
!}
    ! *** MAKE SURE THE FILE IS NEW
    OPEN(ULGR,FILE='EE_DRIFTER.OUT',STATUS='UNKNOWN',FORM='UNFORMATTED')  
    CLOSE(ULGR,STATUS='DELETE')
    OPEN(ULGR,FILE='EE_DRIFTER.OUT',ACTION='WRITE',FORM='UNFORMATTED')  
    JSPD=0  
    VER=101
    WRITE(ULGR) VER
    WRITE(ULGR) TITLE  
    WRITE(ULGR) METHOD
    WRITE(ULGR) NPD,KC
    WRITE(ULGR) TIMEDAY
    WRITE(ULGR)(XLA(NP),YLA(NP),REAL(ZLA(NP),4),NP=1,NPD)
    ![ykchoi 10.04.26
	!FLUSH(ULGR)
	CALL FLUSH(ULGR)
	!ykchoi]
      TIMENEXT=TIMEDAY+LA_FREQ+0.000001  
  ENDIF

  !----NEXT CALL--------------------------- 


!{GEOSR, OIL, CWCHO, 101103
  IF (IDTOX>=4440) THEN 
	CALL OILCHEM
    
    IF(OILTHICK>=THICKLIMIT) THEN
      ALFA = (CFAY_2*CFAY_2/32.0)*(DELTARHO*G*OILVOLINI**2/sqrt(WKVISC))**(1./3.)
      IF(OSPD.EQ.1) THEN
       TRANSTIME = (CFAY_2/CFAY_1)**4 * (OILVOLINI/(G*DELTARHO*WKVISC))**(1./3.)
       DIFFCOEF  = ALFA*(1/SQRT(TRANSTIME))
       ALFA_OLD  = ALFA
       OSPD=0
	  ELSE
	   DIFFCOEF  = ALFA * ((ALFA_OLD/DIFFCOEF)**2 + DT)**(-1./2.)
	   ALFA_OLD  = ALFA
	  ENDIF

	  DIFFVEL = SQRT(2.0*DIFFCOEF/DT)
    ELSE
	  DIFFVEL = 0.0
    ENDIF
  ENDIF
!}

  DO NP=1,NPD
    BEDGEMOVE = .FALSE.
    XLA1 = XLA(NP)
    YLA1 = YLA(NP)
    ZLA1 = ZLA(NP)
    
!{GEOSR, OIL, CWCHO, 101103    
	IF (IDTOX>=4440) THEN
      !EXPLICIT EULER TO DETERMINE THE NEW POSITION OF DRIFTER:
      IF (LLA(NP)<2.OR.BEDGEMOVE.OR.HPLA(NP)<=0) CYCLE    
      CALL DRIFVELCAL(LLA(NP),KLA(NP),NP,U1NP,V1NP,W1NP,U2NP,V2NP,W2NP) !OUT:HOR.VELOCITIES OF DRIFTER NP

	  CALL RANDOM_NUMBER(R1)
      CALL RANDOM_NUMBER(R2)
 
      UOIL = R1*COS(2.*PI*R2)*DIFFVEL
	  VOIL = R1*SIN(2.*PI*R2)*DIFFVEL

	  U1NP=U1NP+UOIL !+UWIND : not use u-vel due wind
	  V1NP=V1NP+VOIL !+VWIND : not use v-vel due wind

      XLA(NP) = XLA1 + DT*U1NP  
      YLA(NP) = YLA1 + DT*V1NP  

      IF(LA_ZCAL==1) THEN
        ZLA(NP) = ZLA1 + DT*W1NP
      ELSE
        ZLA(NP)=HPLA(NP)+BELVLA(NP)-DLA(NP)
      ENDIF
      CALL RANDCAL(LLA(NP),KLA(NP),NP)
      CALL CONTAINER(XLA,YLA,ZLA,LLA,KLA,NP) 
!}		
		
	ELSEIF (ISPD==2.AND.IDTOX<4440) THEN
      !EXPLICIT EULER TO DETERMINE THE NEW POSITION OF DRIFTER:
      IF (LLA(NP)<2.OR.BEDGEMOVE.OR.HPLA(NP)<=0) CYCLE    
      CALL DRIFVELCAL(LLA(NP),KLA(NP),NP,U1NP,V1NP,W1NP,U2NP,V2NP,W2NP) !OUT:HOR.VELOCITIES OF DRIFTER NP
      XLA(NP) = XLA1 + DT*U1NP  
      YLA(NP) = YLA1 + DT*V1NP  
      IF(LA_ZCAL==1) THEN
        ZLA(NP) = ZLA1 + DT*W1NP
      ELSE
        ZLA(NP)=HPLA(NP)+BELVLA(NP)-DLA(NP)  !HP interpolation
      ENDIF
      CALL RANDCAL(LLA(NP),KLA(NP),NP)
      CALL CONTAINER(XLA,YLA,ZLA,LLA,KLA,NP) !IT MUST BE HERE
      
    ELSEIF (ISPD==3.AND.IDTOX<4440) THEN
      !EULER PREDICTOR-CORRECTOR
      IF (LLA(NP)<2.OR.BEDGEMOVE.OR.HPLA(NP)<=0) CYCLE
      CALL DRIFVELCAL(LLA(NP),KLA(NP),NP,U1NP,V1NP,W1NP,U2NP,V2NP,W2NP)
      XLA(NP) = XLA1 + DT*U1NP                   
      YLA(NP) = YLA1 + DT*V1NP                   
      IF(LA_ZCAL==1) THEN
        ZLA(NP) = ZLA1 + DT*W1NP      
      ELSE
        ZLA(NP)=HPLA(NP)+BELVLA(NP)-DLA(NP) !HP interpolation
      ENDIF
      CALL CONTAINER(XLA,YLA,ZLA,LLA,KLA,NP)
      IF (LLA(NP)<2.OR.BEDGEMOVE.OR.HPLA(NP)<=0) CYCLE
      CALL DRIFVELCAL(LLA(NP),KLA(NP),NP,KDX1,KDY1,KDZ1,U2NP,V2NP,W2NP)
      XLA(NP) = XLA1 + 0.5*DT*(U1NP+U2NP) 
      YLA(NP) = YLA1 + 0.5*DT*(V1NP+V2NP)
      IF(LA_ZCAL==1) THEN
        ZLA(NP) = ZLA1 + 0.5*DT*(W1NP+W2NP)
      ELSE
        ZLA(NP)=HPLA(NP)+BELVLA(NP)-DLA(NP)
      ENDIF
      CALL RANDCAL(LLA(NP),KLA(NP),NP)
      CALL CONTAINER(XLA,YLA,ZLA,LLA,KLA,NP)
      
    ELSEIF (ISPD==4.AND.IDTOX<4440) THEN
      !RUNGE-KUTTA 4
      IF (LLA(NP)<2.OR.BEDGEMOVE.OR.HPLA(NP)<=0) CYCLE
      CALL DRIFVELCAL(LLA(NP),KLA(NP),NP,U1NP,V1NP,W1NP,U2NP,V2NP,W2NP)
      KDX1 = DT*U1NP  
      KDY1 = DT*V1NP  
      KDZ1 = DT*W1NP    
      XLA(NP)  = XLA1+0.5*KDX1
      YLA(NP)  = YLA1+0.5*KDY1
      IF(LA_ZCAL==1) THEN
        ZLA(NP)  = ZLA1+0.5*KDZ1
      ELSE
        ZLA(NP)=HPLA(NP)+BELVLA(NP)-DLA(NP)
      ENDIF
      CALL CONTAINER(XLA,YLA,ZLA,LLA,KLA,NP)
      IF (LLA(NP)<2.OR.BEDGEMOVE.OR.HPLA(NP)<=0) CYCLE
      CALL DRIFVELCAL(LLA(NP),KLA(NP),NP,U1NP,V1NP,W1NP,U2NP,V2NP,W2NP)
      KDX2 = 0.5*DT*(U1NP+U2NP)           
      KDY2 = 0.5*DT*(V1NP+V2NP)           
      KDZ2 = 0.5*DT*(W1NP+W2NP) 
      XLA(NP)  = XLA1+0.5*KDX2
      YLA(NP)  = YLA1+0.5*KDY2
      IF(LA_ZCAL==1) THEN
        ZLA(NP)  = ZLA1+0.5*KDZ2
      ELSE
        ZLA(NP)=HPLA(NP)+BELVLA(NP)-DLA(NP)
      ENDIF
      CALL CONTAINER(XLA,YLA,ZLA,LLA,KLA,NP)
      IF (LLA(NP)<2.OR.BEDGEMOVE.OR.HPLA(NP)<=0) CYCLE
      CALL DRIFVELCAL(LLA(NP),KLA(NP),NP,U1NP,V1NP,W1NP,U2NP,V2NP,W2NP)
      KDX3 = 0.5*DT*(U1NP+U2NP)  
      KDY3 = 0.5*DT*(V1NP+V2NP)  
      KDZ3 = 0.5*DT*(W1NP+W2NP) 
      XLA(NP)  = XLA1+KDX3
      YLA(NP)  = YLA1+KDY3
      IF(LA_ZCAL==1) THEN
        ZLA(NP)  = ZLA1+KDZ3
      ELSE
        ZLA(NP)=HPLA(NP)+BELVLA(NP)-DLA(NP)
      ENDIF
      CALL CONTAINER(XLA,YLA,ZLA,LLA,KLA,NP)
      IF (LLA(NP)<2.OR.BEDGEMOVE.OR.HPLA(NP)<=0) CYCLE
      CALL DRIFVELCAL(LLA(NP),KLA(NP),NP,U1NP,V1NP,W1NP,U2NP,V2NP,W2NP)
      KDX4 = DT*U2NP                 
      KDY4 = DT*V2NP                 
      KDZ4 = DT*W2NP   
      XLA(NP) = XLA1+(KDX1+2.0*KDX2+2.0*KDX3+KDX4)/6.0
      YLA(NP) = YLA1+(KDY1+2.0*KDY2+2.0*KDY3+KDY4)/6.0
      IF(LA_ZCAL==1) THEN
        ZLA(NP) = ZLA1+(KDZ1+2.0*KDZ2+2.0*KDZ3+KDZ4)/6.0  
      ELSE
        ZLA(NP)=HPLA(NP)+BELVLA(NP)-DLA(NP)
      ENDIF
      CALL RANDCAL(LLA(NP),KLA(NP),NP)
      CALL CONTAINER(XLA,YLA,ZLA,LLA,KLA,NP)
    ENDIF
  ENDDO

! *** WRITE THE CURRENT TRACK POSITION
  IF (TIMEDAY>=TIMENEXT) THEN
    WRITE(ULGR) TIMEDAY
    WRITE(ULGR) (LLA(NP),XLA(NP),YLA(NP),REAL(ZLA(NP),4),NP=1,NPD) 

!{GEOSR, OIL, CWCHO, 101112
  IF (IDTOX>=4440) THEN
	CALL OUTOIL
  ENDIF
!}
    ![ykchoi 10.04.26
	!FLUSH(ULGR)
	CALL FLUSH(ULGR)
	!ykchoi]
    TIMENEXT = TIMENEXT+LA_FREQ
  ENDIF  
END SUBROUTINE
 
SUBROUTINE DRIFTERINP   ! ********************************************************************
  !READING INPUT DATA OF INITIAL LOCATIONS OF DRIFTERS
  !OUTPUT: NPD,XLA,YLA,ZLA,NP=1:NPD
  !        LA_BEGTI, LA_ENDTI, LA_FREQ,LANDT
  INTEGER(4)::NP,I,J,K
  REAL(RKD) ::XC(4),YC(4),AREA2,RANVAL
  REAL(8),EXTERNAL::DRAND   !IT NEEDS THIS STATEMENT IN CASE OF IMPLICIT NONE
    
  OPEN(ULOC,FILE='DRIFTER.INP',ACTION='READ')
  CALL READSTR(ULOC)
  READ(ULOC,*) LA_ZCAL,LA_PRAN,LA_DIFOP,LA_HORDIF,LA_VERDIF,DEPOP !05 MAY 2009: NEW STRUCTURE 
  CALL READSTR(ULOC)
  READ(ULOC,*) LA_BEGTI, LA_ENDTI, LA_FREQ            !UPDATED 23-04-09
  LA_FREQ = LA_FREQ/1440.                             !Output Frequency 
  CALL READSTR(ULOC)
  READ(ULOC,*) NPD
  if (.not. allocated(XLA)) then 
    ALLOCATE(XLA(NPD),YLA(NPD),ZLA(NPD),DLA(NPD))
    ALLOCATE(LLA(NPD),KLA(NPD),HPLA(NPD),BELVLA(NPD))
  end if
  if (.not. allocated(ZCTR)) then 
    ALLOCATE(ZCTR(0:KC+1))
  end if
  LLA = 0
  KLA = 0  
  HPLA= 0.0
  CALL READSTR(ULOC)
  IF (DEPOP==1) THEN
    DO NP=1,NPD
       ! *** Read Depths
      READ(ULOC,*,ERR=999) XLA(NP),YLA(NP),DLA(NP)
    ENDDO
  ELSE
    DO NP=1,NPD
       ! *** Read Elevations
      READ(ULOC,*,ERR=999) XLA(NP),YLA(NP),ZLA(NP)
    ENDDO
  ENDIF
  CLOSE(ULOC)
  IF(LA_PRAN>0) RANVAL = DRAND(1)
  RETURN
  999 STOP 'DRIFTER.INP READING ERROR!'
END SUBROUTINE

SUBROUTINE READSTR(UINP)   !******************************************************************
  INTEGER(4),INTENT(IN)::UINP
  CHARACTER(200)::STR
  DO WHILE (.TRUE.)
    READ(UINP,'(A)') STR
    STR=ADJUSTL(STR)
    IF (STR(1:1).NE.'*') THEN
      BACKSPACE(UINP)
      RETURN
    ENDIF
  ENDDO
END SUBROUTINE

SUBROUTINE CONTAINER(XLA,YLA,ZLA,LLA,KLA,NP)   !**********************************************
  !DETERMINING LLA,KLA,BELVLA,HPLA FOR THE FIRST CALL
  !UPDATING XLA,YLA,LLA,KLA,BELVLA,HPLA FOR THE NEXT CALL
  !FOR EACH DRIFTER (XLA,YLA,ZLA)
  !BY FINDING THE NEAREST CELL CENTTROID
  !THEN EXPANDING TO THE NEIGHBOUR CELLS
  !HP(LIJ(I,J))     : WATER DEPTH = WATER SUR. - BELV
  !BELV(LIJ(I,J))   : BOTTOM ELEVATION OF A CELL
  !BELVLA           : BED ELEVATION AT DRIFTER NI POSITION
  !HPLA             : WATER DEPTH AT DRIFTER NI POSITION
  !DLON(L),L=2:LA ? : CELL CENTROID XCEL = XCOR(L,5)
  !DLAT(L),L=2:LA ? : CELL CENTROID YCEL = YCOR(L,5)
  !DZC(K),K=1:KC    : LAYER THICKNESS
  !LIJ(1:ICM,1:JCM)  
  !INPUT:
  !IF DEPOP=0: XLA,YLA,ZLA,XCOR(L,5),YCOR(L,5),BELV,HP
  !IF DEPOP=1: XLA,YLA,XCOR(L,5),YCOR(L,5),BELV,HP,DLA
  !OUTPUT:
  !  XLA,YLA,LLA(NP),KLA(NP),BELVLA(NP),HPLA(NP)
  REAL(RKD) ,INTENT(INOUT)::XLA(:),YLA(:)
  INTEGER(4),INTENT(IN),OPTIONAL::NP
  INTEGER(4),INTENT(INOUT)::LLA(:),KLA(:)
  REAL(RKD) ,INTENT(INOUT)::ZLA(:)
  INTEGER(4)::IPD,NPSTAT,LLA1,LLA2,KLA1
  INTEGER(4)::NI,LMILOC(1),K,L,N1,N2,I,J,ILN,JLN
  INTEGER(4)::I1,I2,J1,J2,ITER,IPMC,JPMC
  REAL(RKD) ::RADLA(LA),ZSIG,SCALE 
  LOGICAL(4)::MASK1,MASK2,MASK3,MASK4
  LOGICAL(4)::CMASK,CMASK1,CMASK2,CMASK3,CMASK4
  LOGICAL(4)::CPOS1,CPOS2,CPOS3,CPOS4

  IF (PRESENT(NP)) THEN
    N1=NP
    N2=NP
    IF (LLA(NP)<2) RETURN
  ELSE
    N1=1
    N2=NPD
    ZCTR(0:KC)=ZZ(0:KC)
    ZCTR(KC+1)=Z(KC)
  ENDIF
  DO NI=N1,N2 
    !DETERMINE THE NEAREST CELL CENTROID 
    IF (PRESENT(NP)) THEN
      !FOR THE NEXT CALL
      ILN = IL(LLA(NI))        !I OF THE CELL CONTAINING DRIFTER AT PREVIOUS TIME
      JLN = JL(LLA(NI))        !J OF THE CELL CONTAINING DRIFTER AT PREVIOUS TIME    
      LLA1 = LLA(NI)           !L OF THE CELL CONTAINING DRIFTER AT PREVIOUS TIME
    ELSE  
      !FOR THE FIRST CALL                     
      RADLA(2:LA) = SQRT((XLA(NI)-XCOR(2:LA,5))**2+(YLA(NI)-YCOR(2:LA,5))**2) !MAY 11, 2009
      LMILOC = MINLOC(RADLA(2:LA))
      ILN = IL(LMILOC(1)+1)    !I OF THE NEAREST CELL FOR DRIFTER
      JLN = JL(LMILOC(1)+1)    !J OF THE NEAREST CELL FOR DRIFTER      
    ENDIF  

    !DETERMINE THE CELL CONTAINING THE DRIFTER WITHIN 9 CELLS: LLA(NI)
    NPSTAT = 0
    I1 = MAX(1,ILN-1)
    I2 = MIN(ILN+1,ICM)
    J1 = MAX(1,JLN-1)
    J2 = MIN(JLN+1,JCM)
    LOOP:DO J=J1,J2
      DO I=I1,I2
        L = LIJ(I,J)
        IF (L<2) CYCLE
        !IF (INSIDECELL(L,NI)) THEN
        
        IF (INSIDECELL(L,XLA(NI),YLA(NI))) THEN
        
        
          IF (PRESENT(NP)) THEN
            ! *** PARTICLE IS INSIDE CURRENT CELL
            !DEALING WITH THE WALLS
            MASK1 = I==ILN+1.AND.SUB(LIJ(I  ,J  ))<0.5
            MASK2 = I==ILN-1.AND.SUB(LIJ(I+1,J  ))<0.5
            MASK3 = J==JLN+1.AND.SVB(LIJ(I  ,J  ))<0.5
            MASK4 = J==JLN-1.AND.SVB(LIJ(I  ,J+1))<0.5
            
            CMASK1=(SUB(LIJ(ILN+1,JLN  ))<0.5.AND.SVB(LIJ(ILN  ,JLN+1))<0.5) 
            CMASK2=(SUB(LIJ(ILN  ,JLN  ))<0.5.AND.SVB(LIJ(ILN  ,JLN+1))<0.5) 
            CMASK3=(SUB(LIJ(ILN  ,JLN  ))<0.5.AND.SVB(LIJ(ILN  ,JLN  ))<0.5) 
            CMASK4=(SUB(LIJ(ILN+1,JLN  ))<0.5.AND.SVB(LIJ(ILN  ,JLN  ))<0.5) 
            
            CPOS1 = (I>=ILN  .AND.J==JLN+1).OR.(I==ILN+1.AND.J>=JLN  )
            CPOS2 = (I==ILN-1.AND.J>=JLN  ).OR.(I<=ILN  .AND.J==JLN+1)
            CPOS3 = (I==ILN-1.AND.J<=JLN  ).OR.(I<=ILN  .AND.J==JLN-1)
            CPOS4 = (I>=ILN  .AND.J==JLN-1).OR.(I==ILN+1.AND.J<=JLN  )

            CMASK = (CMASK1.AND.CPOS1).OR.(CMASK2.AND.CPOS2).OR.&
                    (CMASK3.AND.CPOS3).OR.(CMASK4.AND.CPOS4)

            SCALE=1 
                      
            IF    ((MASK1.OR.MASK2).AND..NOT.CMASK) THEN
              CALL EDGEMOVE(LLA1,NI,ILN,JLN,1,SCALE)

            ELSEIF((MASK3.OR.MASK4).AND..NOT.CMASK) THEN
              CALL EDGEMOVE(LLA1,NI,ILN,JLN,2,SCALE)

            ELSEIF(CMASK1.AND.CPOS1) THEN
              CALL EDGEMOVE(LLA1,NI,ILN,JLN,5,SCALE) 
              
            ELSEIF(CMASK2.AND.CPOS2) THEN
              CALL EDGEMOVE(LLA1,NI,ILN,JLN,6,SCALE) 
              
            ELSEIF(CMASK3.AND.CPOS3) THEN
              CALL EDGEMOVE(LLA1,NI,ILN,JLN,7,SCALE) 

            ELSEIF(CMASK4.AND.CPOS4) THEN
              CALL EDGEMOVE(LLA1,NI,ILN,JLN,8,SCALE) 
    
            ELSE
              LLA(NI)=L
            ENDIF

          ELSE !FIRST CALL
            LLA(NI)=L
          ENDIF
          NPSTAT = 1          
          EXIT LOOP          
        ENDIF
      ENDDO
    ENDDO LOOP
    
    ! *** CHECK IF THE PARTICLE IS INSIDE THE MODEL DOMAIN
    IF (NPSTAT==0.AND.PRESENT(NP)) THEN
      ! *** PARTICLE IS OUTSIDE DOMAIN
      ! *** RECOMPUTE THE DISTANCE OF NEW POSITION
      ! *** SO THAT IT IS BACK TO PREVIOUS CELL ON THE BORDER
      MASK1 = LIJ(ILN+1,JLN  )>=2.AND.LIJ(ILN+1,JLN  )<=LA
      MASK2 = LIJ(ILN-1,JLN  )>=2.AND.LIJ(ILN-1,JLN  )<=LA
      MASK3 = LIJ(ILN  ,JLN+1)>=2.AND.LIJ(ILN  ,JLN+1)<=LA
      MASK4 = LIJ(ILN  ,JLN-1)>=2.AND.LIJ(ILN  ,JLN-1)<=LA  
      SCALE = 1 
      
      IF     (MASK1.AND.MASK2.AND..NOT.(MASK3.AND.MASK4)) THEN
        CALL EDGEMOVE(LLA1,NI,ILN,JLN,2,SCALE)
        
      ELSEIF (MASK3.AND.MASK4.AND..NOT.(MASK1.AND.MASK2)) THEN
        CALL EDGEMOVE(LLA1,NI,ILN,JLN,1,SCALE)
     
      ELSEIF (MASK1.AND.MASK4.AND..NOT.(MASK2.OR.MASK3)) THEN
        CALL EDGEMOVE(LLA1,NI,ILN,JLN,6,SCALE)

      ELSEIF (MASK2.AND.MASK4.AND..NOT.(MASK1.OR.MASK3)) THEN
        CALL EDGEMOVE(LLA1,NI,ILN,JLN,5,SCALE)

      ELSEIF (MASK1.AND.MASK3.AND..NOT.(MASK2.OR.MASK4)) THEN
        CALL EDGEMOVE(LLA1,NI,ILN,JLN,7,SCALE)

      ELSEIF (MASK2.AND.MASK3.AND..NOT.(MASK1.OR.MASK4)) THEN
        CALL EDGEMOVE(LLA1,NI,ILN,JLN,8,SCALE)

      ELSE
        CALL EDGEMOVE(LLA1,NI,ILN,JLN,0,SCALE)
      ENDIF     
      
      LLA2=LLA(NI)
      IF (ANY(LPBN==LLA(NI)).OR.ANY(LPBS==LLA(NI)).OR. &
          ANY(LPBE==LLA(NI)).OR.ANY(LPBW==LLA(NI)))   THEN
        CALL SET_DRIFTER_OUT        
        PRINT '(A36,I6)','OPEN BOUNDARY, DRIFTER IS OUTSIDE:',NI 

      ELSEIF(ANY(LQS==LLA(NI)).AND.QSUM(LLA(NI),KLA(NI))<0) THEN
        CALL SET_DRIFTER_OUT
        PRINT '(A36,I6)','WITHDAWAL CELL, DRIFTER IS OUTSIDE:',NI

      ELSEIF (ANY(IQWRU==IL(LLA(NI))).AND.ANY(JQWRU==JL(LLA(NI)))) THEN
        CALL SET_DRIFTER_OUT
        ! ***  RETURN DRIFTER
        DO K=1,NQWR
          IF( IQWRU(K)==IL(LLA2).AND.JQWRU(K)==JL(LLA2).AND.KQWRU(K)==KLA(NI) ) THEN
            LLA(NI)=LIJ(IQWRD(K),JQWRD(K))
            LLA2=LLA(NI)
            XLA(NI)= XCOR(LLA2,5)
            YLA(NI)= YCOR(LLA2,5)
            ZLA(NI)= BELVLA(LLA2)+HPLA(LLA2)*ZZ(KQWRD(K)) 
            BEDGEMOVE = .TRUE.
            EXIT
          ENDIF
        ENDDO
        IF( LLA(NI)==1 )THEN
          PRINT '(A36,I6)','WITHDRAWAL/RETURN, DRIFTER IS OUTSIDE:',NI
        ENDIF

      ELSEIF (ANY(IQCTLU==IL(LLA(NI))).AND.ANY(JQCTLU==JL(LLA(NI)))) THEN
        ! *** HYDRAULIC STRUCTURE.  RETURN DRIFTER TO DOWNSTREAM CELL, IF ANY
        CALL SET_DRIFTER_OUT
        ! ***  RETURN DRIFTER, IF POSSIBLE
        DO K=1,NQCTL
          IF( IQCTLU(K)==IL(LLA2).AND.JQCTLU(K)==JL(LLA2) .AND. IQCTLD(K)>0 ) THEN
            LLA(NI)=LIJ(IQCTLD(K),JQCTLD(K))
            XLA(NI)= XCOR(LLA(NI),5)
            YLA(NI)= YCOR(LLA(NI),5)

!{GEOSR, GATE-OIL, CWCHO, 101119
!{GEOSR, GATE-OIL, YSSONG, 101125  
!			IF(IDTOX<4440) THEN
			IF(IDTOX>.0.AND.IDTOX<4440) THEN
            ZLA(NI)= BELVLA(LLA(NI))+HPLA(LLA(NI))/2.
			ENDIF
!}
!}
            BEDGEMOVE = .TRUE.
            EXIT
          ENDIF
        ENDDO
        IF( LLA(NI)==1 )THEN
          PRINT '(A40,I6)','HYDRAULIC STRUCTURE, DRIFTER IS OUTSIDE:',NI
        ENDIF
        
      ENDIF
      
    ELSEIF (NPSTAT==0.AND..NOT.PRESENT(NP)) THEN
      !FOR THE FIRST CALL
      LLA(NI)=1

    ENDIF
    
    !DETERMINE BOTTOM ELEVATION AND TOTAL WATER DEPTH OF DRIFTERS FOR EVERYTIME
    IF (LLA(NI)>=2) CALL DRIFTERWDEP(LLA(NI),NI,BELVLA(NI),HPLA(NI))
        
    !CONVERT DLA TO ZLA
    IF (.NOT.PRESENT(NP).AND.DEPOP==1) ZLA(NI)=HPLA(NI)+BELVLA(NI)-DLA(NI)
    
    IF (LLA(NI)>=2) THEN
      CALL DRIFTERLAYER(LLA(NI),NI,BELVLA(NI),HPLA(NI),KLA(NI),ZLA(NI))     
    ENDIF
    
  ENDDO

  CONTAINS
   SUBROUTINE SET_DRIFTER_OUT
   XLA(NI)= XLA1  
   YLA(NI)= YLA1  
   ZLA(NI)= ZLA1  
   LLA(NI)= 1
   END SUBROUTINE
   
END SUBROUTINE

SUBROUTINE AREACAL(XC,YC,AREA)   ! ***********************************************************
  !AREA CALCULATION OF A POLYGON
  !WITH GIVEN VEXTICES (XC,YC)
  REAL(RKD),INTENT(IN) ::XC(:),YC(:)
  REAL(RKD),INTENT(OUT)::AREA
  REAL(RKD)::XVEC(2),YVEC(2)
  INTEGER(4)::NPOL,K
  NPOL = SIZE(XC)
  AREA = 0
  XVEC(1)=XC(2)-XC(1)
  YVEC(1)=YC(2)-YC(1)
  DO K=3,NPOL
    XVEC(2) = XC(K)-XC(1)
    YVEC(2) = YC(K)-YC(1)
    AREA = AREA+0.5*ABS( XVEC(1)*YVEC(2)-XVEC(2)*YVEC(1))
    XVEC(1)=XVEC(2)
    YVEC(1)=YVEC(2)
  ENDDO
END SUBROUTINE

SUBROUTINE DRIFVELCAL(LNI,KNI,NI,U1NI,V1NI,W1NI,U2NI,V2NI,W2NI)   ! **************************
  !CALCULATING VELOCITY COMPONENTS AT DRIFTER LOCATION
  !BY USING INVERSE DISTANCE POWER 2 INTERPOLATION
  !FOR VELOCITY COMPONENTS AT THE CENTROID OF POLYGON
  INTEGER(4),INTENT(IN )::LNI,KNI,NI
  REAL(RKD) ,INTENT(OUT)::U1NI,V1NI,W1NI,U2NI,V2NI,W2NI
  INTEGER(4)::ICELL,JCELL,I,J,L,LN,K1,K2,KZ1,KZ2
  REAL(RKD)::RAD2,SU1,SU2,SU3,SV1,SV2,SV3,SW1,SW2,SW3
  REAL(RKD)::UTMPB,VTMPB,UTMPB1,VTMPB1,WTMPB,WTMPB1
  REAL(RKD)::VELEK,VELNK,VELEK1,VELNK1,ZSIG
  REAL(RKD)::UKB,UKT,VKB,VKT,UKB1,UKT1,VKB1,VKT1
  LOGICAL(4)::CRN1,CRN2,CRN3,CRN4

  ICELL = IL(LNI)
  JCELL = JL(LNI)
  SU1=0
  SU2=0
  SU3=0
  SV1=0
  SV2=0
  SV3=0
  SW1=0
  SW2=0
  SW3=0
  DO J=JCELL-1,JCELL+1
    DO I=ICELL-1,ICELL+1
      L = LIJ(I,J)
      IF (L.GE.2) THEN
        LN   = LNC(L)           !L index of the cell above (North)
        CRN1 = I==ICELL+1.AND.SUB(LIJ(I  ,J  ))<0.5
        CRN2 = I==ICELL-1.AND.SUB(LIJ(I+1,J  ))<0.5
        CRN3 = J==JCELL-1.AND.SVB(LIJ(I  ,J+1))<0.5
        CRN4 = J==JCELL+1.AND.SVB(LIJ(I  ,J  ))<0.5   
        IF (CRN1.OR.CRN2.OR.CRN3.OR.CRN4) CYCLE

       !CALCULATING HOR.VELOCITY COMPONENTS AT CENTROID
        RAD2 = MAX((XLA(NI)-XCOR(L,5))**2+(YLA(NI)-YCOR(L,5))**2,1.0E-8)
        ZSIG = (ZLA(NI)-BELVLA(NI))/HPLA(NI)
        ZSIG = MAX(0.0,MIN(1.0,ZSIG))
        ZLA(NI)=ZSIG*HPLA(NI)+BELVLA(NI)
        IF(ZSIG>=ZZ(KNI)) THEN
          K1 = KNI
          K2 = MIN(KNI+1,KC)
          KZ1= KNI
          KZ2= KNI+1
        ELSE
          K1 = MAX(1,KNI-1)
          K2 = KNI
          KZ1= KNI-1
          KZ2= KNI
        ENDIF
        UKB =0.5*STCUV(L)*(RSSBCE(L)*U (L+1,K1)*SUB(L+1)+RSSBCW(L)*U (L,K1)*SUB(L))       
        UKB1=0.5*STCUV(L)*(RSSBCE(L)*U1(L+1,K1)*SUB(L+1)+RSSBCW(L)*U1(L,K1)*SUB(L))     
        VKB =0.5*STCUV(L)*(RSSBCN(L)*V (LN, K1)*SVB(LN) +RSSBCS(L)*V (L,K1)*SVB(L))     
        VKB1=0.5*STCUV(L)*(RSSBCN(L)*V1(LN, K1)*SVB(LN) +RSSBCS(L)*V1(L,K1)*SVB(L))   

        UKT =0.5*STCUV(L)*(RSSBCE(L)*U (L+1,K2)*SUB(L+1)+RSSBCW(L)*U (L,K2)*SUB(L))       
        UKT1=0.5*STCUV(L)*(RSSBCE(L)*U1(L+1,K2)*SUB(L+1)+RSSBCW(L)*U1(L,K2)*SUB(L))     
        VKT =0.5*STCUV(L)*(RSSBCN(L)*V (LN, K2)*SVB(LN) +RSSBCS(L)*V (L,K2)*SVB(L))     
        VKT1=0.5*STCUV(L)*(RSSBCN(L)*V1(LN, K2)*SVB(LN) +RSSBCS(L)*V1(L,K2)*SVB(L))   

        UTMPB = (UKT -UKB )*(ZSIG-ZCTR(KZ1))/(ZCTR(KZ2)-ZCTR(KZ1))+UKB
        UTMPB1= (UKT1-UKB1)*(ZSIG-ZCTR(KZ1))/(ZCTR(KZ2)-ZCTR(KZ1))+UKB1
        VTMPB = (VKT -VKB )*(ZSIG-ZCTR(KZ1))/(ZCTR(KZ2)-ZCTR(KZ1))+VKB
        VTMPB1= (VKT1-VKB1)*(ZSIG-ZCTR(KZ1))/(ZCTR(KZ2)-ZCTR(KZ1))+VKB1
        
        !INTERPOLATION FOR VERTICAL VELOCITY COMPONENT
        WTMPB = (W (L,KNI)-W (L,KNI-1))*(ZSIG-Z(KNI-1))/(Z(KNI)-Z(KNI-1))+W (L,KNI-1)
        WTMPB1= (W1(L,KNI)-W1(L,KNI-1))*(ZSIG-Z(KNI-1))/(Z(KNI)-Z(KNI-1))+W1(L,KNI-1)

        !ROTATION
        VELEK=CUE(L)*UTMPB+CVE(L)*VTMPB  
        VELNK=CUN(L)*UTMPB+CVN(L)*VTMPB  
        VELEK1=CUE(L)*UTMPB1+CVE(L)*VTMPB1  
        VELNK1=CUN(L)*UTMPB1+CVN(L)*VTMPB1  
        SU1=SU1+VELEK1/RAD2
        SU2=SU2+VELEK /RAD2
        SU3=SU3+1._8/RAD2
        SV1=SV1+VELNK1/RAD2
        SV2=SV2+VELNK /RAD2
        SV3=SV3+1._8/RAD2
        SW1=SW1+WTMPB1/RAD2
        SW2=SW2+WTMPB /RAD2
        SW3=SW3+1._8/RAD2

      ENDIF
    ENDDO
  ENDDO
  U1NI = SU1/SU3
  U2NI = SU2/SU3
  V1NI = SV1/SV3
  V2NI = SV2/SV3
  W1NI = SW1/SW3
  W2NI = SW2/SW3

END SUBROUTINE

SUBROUTINE RANDCAL(L,K,NP)   ! ***************************************************************
  INTEGER,INTENT(IN)::L,K,NP
  REAL(8),EXTERNAL::DRAND
  REAL(RKD)::COEF
  IF (LA_PRAN==1.OR.LA_PRAN==3) THEN
    IF (LA_DIFOP==0) THEN
      COEF = SQRT(2*AH(L,K)*DT)
    ELSE
      COEF = SQRT(2*LA_HORDIF*DT)
    ENDIF
    XLA(NP) = XLA(NP) + (2*DRAND(0)-1)*COEF
    YLA(NP) = YLA(NP) + (2*DRAND(0)-1)*COEF
  ENDIF
  IF (LA_PRAN.GE.2.AND.LA_ZCAL==1) THEN
    IF (LA_DIFOP==0) THEN
      COEF = SQRT(2*AV(L,K)*DT)
    ELSE
      COEF = SQRT(2*LA_VERDIF*DT)
    ENDIF
    ZLA(NP) = ZLA(NP)+ (2*DRAND(0)-1)*COEF
  ENDIF
END SUBROUTINE

SUBROUTINE EDGEMOVE(LLA1,NI,ILN,JLN,NCASE,SCALE)    ! ****************************************
  !I,J,L:INDICES OF DRIFTER AT CURRENT POSITION
  INTEGER(4),INTENT(IN)::LLA1,NI,ILN,JLN,NCASE
  REAL(RKD), INTENT(IN)::SCALE
  REAL(RKD)::UTMPB,VTMPB,VELM
  INTEGER(4)::LN,KLA1

  KLA1 = KLA(NI)
  LN = LNC(LLA1)  !
  UTMPB = 0.5*STCUV(LLA1)*(RSSBCE(LLA1)*U1(LLA1+1,KLA(NI))+RSSBCW(LLA1)*U1(LLA1,KLA(NI)))  
  VTMPB = 0.5*STCUV(LLA1)*(RSSBCN(LLA1)*V1(LN,    KLA(NI))+RSSBCS(LLA1)*V1(LLA1,KLA(NI))) 
  VELM  = SCALE*MAX(ABS(UTMPB),ABS(VTMPB),1.0E-2)

  IF (NCASE==1) THEN
    ! *** MOVE ALONG THE V DIRECTTION    
    !UTMPB = -SCALE*UTMPB
    UTMPB = -SIGNV(UTMPB)*VELM
    IF (ABS(UTMPB)<1.D-2) UTMPB = 1.D-2*SIGNV(UTMPB)
    CALL RESET_LLA(ILN,ILN,JLN-1,JLN+1)
    IF (BEDGEMOVE) RETURN
    UTMPB = -UTMPB
    CALL RESET_LLA(ILN,ILN,JLN-1,JLN+1)
    IF (BEDGEMOVE) RETURN

  ELSEIF (NCASE==2) THEN
    ! *** MOVE ALONG THE U DIRECTTION
    !VTMPB = -SCALE*VTMPB 
    VTMPB = -SIGNV(VTMPB)*VELM
    IF (ABS(VTMPB)<1.D-2) VTMPB = 1.D-2*SIGNV(VTMPB)
    CALL RESET_LLA(ILN-1,ILN+1,JLN,JLN)
    IF (BEDGEMOVE) RETURN
    VTMPB = -VTMPB
    CALL RESET_LLA(ILN-1,ILN+1,JLN,JLN)
    IF (BEDGEMOVE) RETURN

  ELSEIF (NCASE==5) THEN  
    !UPPER-R CORNER IS LIMITTED
    UTMPB = -VELM
    VTMPB = -VELM
    CALL RESET_LLA(ILN-1,ILN,JLN-1,JLN)
    IF (BEDGEMOVE) RETURN

  ELSEIF (NCASE==6) THEN 
    !UPER-L CORNER IS LIMITTED
    UTMPB =  VELM
    VTMPB = -VELM
    CALL RESET_LLA(ILN,ILN+1,JLN-1,JLN)
    IF (BEDGEMOVE) RETURN

  ELSEIF (NCASE==7) THEN 
    !LOWER-L CORNER IS LIMITTED
    UTMPB = VELM
    VTMPB = VELM
    CALL RESET_LLA(ILN,ILN+1,JLN,JLN+1)
    IF (BEDGEMOVE) RETURN

  ELSEIF (NCASE==8) THEN 
    !LOWER-R CORNER IS LIMITTED
    UTMPB = -VELM
    VTMPB =  VELM
    CALL RESET_LLA(ILN-1,ILN,JLN,JLN+1)
    IF (BEDGEMOVE) RETURN

  ENDIF 

  XLA(NI)= XLA1  
  YLA(NI)= YLA1  
  ZLA(NI)= ZLA1 
  LLA(NI)= LLA1
  
  CONTAINS
   SUBROUTINE RESET_LLA(I1,I2,J1,J2)
   INTEGER(4),INTENT(IN)::I1,I2,J1,J2
   INTEGER(4)::I,J,L
   REAL(RKD)::VELEK,VELNK

   VELEK =CUE(LLA1)*UTMPB+CVE(LLA1)*VTMPB  
   VELNK =CUN(LLA1)*UTMPB+CVN(LLA1)*VTMPB      
   XLA(NI)=XLA1+ DT*VELEK  
   YLA(NI)=YLA1+ DT*VELNK  
   DO J=J1,J2
     DO I=I1,I2
       L = LIJ(I,J)
       IF (L<2) CYCLE
       !IF (INSIDECELL(L,NI)) THEN
       
       IF (INSIDECELL(L,XLA(NI),YLA(NI))) THEN

         LLA(NI)=L
         BEDGEMOVE = .TRUE.
         RETURN
       ENDIF  
     ENDDO
   ENDDO   
   END SUBROUTINE
  
END SUBROUTINE

FUNCTION INSIDECELL(L,XM,YM) RESULT(INSIDE)   ! **********************************************
  LOGICAL(4)::INSIDE
  INTEGER(4),INTENT(IN)::L
  REAL(RKD) ,INTENT(IN)::XM,YM
  REAL(RKD) ::XC(6),YC(6),AREA2

  XC(1) = XM 
  YC(1) = YM 
  XC(2:5)=XCOR(L,1:4)
  YC(2:5)=YCOR(L,1:4)
  XC(6) = XC(2)
  YC(6) = YC(2)
  CALL AREACAL(XC,YC,AREA2)
  IF (ABS(AREA2-AREA(L))<=1D-6) THEN
    INSIDE=.TRUE.
  ELSE 
    INSIDE=.FALSE.
  ENDIF
END FUNCTION

SUBROUTINE DRIFTERWDEP(LNI,NI,BELVNI,HPNI)   !************************************************
  !INTERPOLATION OF THE TOTAL WATER DEPTH AND BOTTOM ELEVATION
  !FOR THE DRIFTER NI AT EACH TIME INSTANT AND EACH LOCATION
  INTEGER(4),INTENT(IN)::LNI,NI
  REAL(RKD),INTENT(OUT)::BELVNI,HPNI
  INTEGER(4)::ICELL,JCELL,L,I,J
  REAL(RKD) ::BELVNI1,BELVNI2,RAD2,ZETA

  ICELL = IL(LNI)
  JCELL = JL(LNI)
  BELVNI1=0.0
  BELVNI2=0.0
  DO J=JCELL-1,JCELL+1
    DO I=ICELL-1,ICELL+1
      L = LIJ(I,J)
      IF (L.GE.2) THEN
        RAD2 = MAX((XLA(NI)-XCOR(L,5))**2+(YLA(NI)-YCOR(L,5))**2,1.0E-8)     
        BELVNI1=BELVNI1+BELV(L)/RAD2
        BELVNI2=BELVNI2+1._8/RAD2
      ENDIF
    ENDDO
  ENDDO
  BELVNI = BELVNI1/BELVNI2
  ZETA = HP(LNI)+BELV(LNI)
  HPNI = ZETA-BELVNI 

END SUBROUTINE

SUBROUTINE DRIFTERLAYER(LNI,NI,BELVNI,HPNI,KLN,ZLN)
  !RECALCULATE ZLA(NI)
  !DETERMINE KLA(NI)
  INTEGER(4),INTENT(IN)::LNI,NI
  REAL(RKD), INTENT(IN)::BELVNI,HPNI
  INTEGER(4),INTENT(OUT)::KLN
  REAL(RKD), INTENT(INOUT)::ZLN
  INTEGER(4)::K
  REAL(RKD) ::ZSIG
  IF (LNI.GE.2) THEN
    ZSIG = (ZLN-BELVNI)/HPNI
    ZSIG = MAX(0.0,MIN(1.0,ZSIG))
    ZLN=ZSIG*HPNI+BELVNI  !IF ZSIG>1 OR ZSIG<0
    DO K=1,KC
      IF(SUM(DZC(1:K))>=ZSIG) THEN
        KLN = K
        EXIT
      ENDIF
    ENDDO
  ENDIF
END SUBROUTINE

FUNCTION SIGNV(V)
REAL(RKD),INTENT(IN)::V
INTEGER(4)::SIGNV
IF (V>=0) THEN
  SIGNV= 1
ELSE
  SIGNV=-1
ENDIF
END FUNCTION

SUBROUTINE AREA_CENTRD
 !DETERMINING CELLCENTROID OF ALL CELLS
 !AND CALCULATING THE AREA OF EACH CELL
 INTEGER(4)::I,J,K
 REAL(RKD)::XC(4),YC(4),AREA2
 OPEN(UCOR,FILE='CORNERS.INP',ACTION='READ')
 CALL READSTR(UCOR)
 if (.not. allocated(XCOR)) ALLOCATE(XCOR(LA,5),YCOR(LA,5),AREA(LA))
 XCOR = 0
 YCOR = 0
 AREA = 0
 DO WHILE(.TRUE.)
   READ(UCOR,*,END=100,ERR=998) I,J,(XCOR(LIJ(I,J),K),YCOR(LIJ(I,J),K),K=1,4)
   XC(1:4) = XCOR(LIJ(I,J),1:4)
   YC(1:4) = YCOR(LIJ(I,J),1:4)
   CALL AREACAL(XC,YC,AREA2)
   AREA(LIJ(I,J)) = AREA2
   ! *** STORE THE CELL CENTROID IN INDEX=5
   XCOR(LIJ(I,J),5) = 0.25*SUM(XC)        
   YCOR(LIJ(I,J),5) = 0.25*SUM(YC)
 ENDDO
 PRINT *,'DRIFTER: NUMBER OF DRIFTERS INITIALZED: ',NPD
 100 CLOSE(UCOR)
 RETURN
 998 STOP 'CORNERS.INP READING ERROR!'
 END SUBROUTINE
 
END MODULE