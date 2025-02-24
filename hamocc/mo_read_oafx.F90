! Copyright (C) 2021-2022  J. Schwinger
!
! This file is part of BLOM/iHAMOCC.
!
! BLOM is free software: you can redistribute it and/or modify it under the
! terms of the GNU Lesser General Public License as published by the Free 
! Software Foundation, either version 3 of the License, or (at your option) 
! any later version. 
!
! BLOM is distributed in the hope that it will be useful, but WITHOUT ANY 
! WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS 
! FOR A PARTICULAR PURPOSE. See the GNU Lesser General Public License for
! more details. 
!
! You should have received a copy of the GNU Lesser General Public License 
! along with BLOM. If not, see https://www.gnu.org/licenses/.


module mo_read_oafx
!******************************************************************************
!
!   J.Schwinger             *NORCE Climate, Bergen*             2022-08-24
!
! Modified
! --------
!  T. Bourgeois,     *NORCE climate, Bergen*   2023-01-31
!  - add ramping-up scenario
!  - add ability to define parameters from BLOM namelist
!
!  T. Bourgeois,     *NORCE climate, Bergen*   2023-02-09
!  - add ability to use an OA input file
!
! Purpose
! -------
!  -Routines for reading ocean alkalinization fluxes from netcdf files
!
!
! Description:
! ------------
!  The routine get_oafx reads a flux of alkalinity from file (or, for simple
!  cases, constructs an alkalinity flux field from scratch). The alkalinity
!  flux is then passed to hamocc4bcm where it is applied to the top-most model 
!  layer by a call to apply_oafx (mo_apply_oafx).
!
!  Ocean alkalinization is activated through a logical switch 'do_oalk' read
!  from HAMOCC's bgcnml namelist. If ocean alkalinization is activated, a valid
!  name of an alkalinisation scenario (defined in this module, see below) needs
!  to be provided via HAMOCC's bgcnml namelist (variable oalkscen). For the
!  'file' scenario, the file name (including the full path) of the
!  corresponding OA-scenario input file needs to be provided (variable
!  oalkfile). If the input file is not found, an error will be issued. The
!  input data must be already pre-interpolated to the ocean grid.
!
!  Currently available ocean alkalinisation scenarios:
!  (for 'const' and 'ramp' scenarios, flux and latitude range can be defined in
!  the namelist, default values are defined):
!    -'const':        constant alkalinity flux applied to the surface ocean
!                     between two latitudes. No input file needed.
!    -'ramp':         ramping-up alkalinity flux from 0 Pmol yr-1 to a maximum
!                     value between two specified years and kept constant
!                     onward, applied to the surface ocean between two
!                     latitudes. No input file needed.
!    -'file':         Read monthly 2D field in kmol ALK m-2 yr-1 from a file
!                     defined with the variable oalkfile.
!
!  -subroutine ini_read_oafx
!     Initialise the module
!
!  -subroutine get_oafx
!     Gets the alkalinity flux to apply at a given time.
!
!
!******************************************************************************
  implicit none

  private
  public :: ini_read_oafx,get_oafx,oalkscen,oalkfile
 
  character(len=128), save :: oalkscen   =''
  character(len=512), save :: oalkfile   =''
  real,allocatable,   save :: oalkflx(:,:)
  integer,            save :: startyear,endyear

  real, parameter          :: Pmol2kmol  = 1.0e12
  
  ! Parameter used in the definition of alkalinization scenarios not based on
  ! an input file. The following scenarios are defined in this module:
  !
  !  const         Constant homogeneous addition of alkalinity between latitude
  !                cdrmip_latmin and latitude cdrmip_latmax
  !  ramp          Linear increase of homogeneous addition from 0 to addalk
  !                Pmol ALK/yr-1 from year ramp_start to year ramp_end between
  !                latitude cdrmip_latmin and latitude cdrmip_latmax
  !
  real, protected :: addalk        = 0.135 ! Pmol alkalinity/yr added in the
                                           ! scenarios. Read from namelist file
                                           ! to overwrite default value.
  real, protected :: cdrmip_latmax =  70.0 ! Min and max latitude where
  real, protected :: cdrmip_latmin = -60.0 ! alkalinity is added according
                                           ! to the CDRMIP protocol. Read from
                                           ! namelist file to overwrite default
                                           ! value.
  integer, protected :: ramp_start = 2025  ! In 'ramp' scenario, start at
  integer, protected :: ramp_end   = 2035  ! 0 Pmol/yr in ramp_start, and max
                                           ! addalk Pmol/yr in ramp_end.
                                           ! Read from namelist file to
                                           ! overwrite default value.

  logical,   save :: lini = .false.

!******************************************************************************
contains



subroutine ini_read_oafx(kpie,kpje,pdlxp,pdlyp,pglat,omask)
!******************************************************************************
!
!     J.Schwinger               *NORCE Climate, Bergen*         2021-11-15
!
! Purpose
! -------
!  -Initialise the alkalinization module.
!
! Changes: 
! --------
!
! Parameter list:
! ---------------
!  *INTEGER* *kpie*       - 1st dimension of model grid.
!  *INTEGER* *kpje*       - 2nd dimension of model grid.
!  *REAL*    *pdlxp*      - size of grid cell (longitudinal) [m].
!  *REAL*    *pdlyp*      - size of grid cell (latitudinal) [m].
!  *REAL*    *pglat*      - latitude grid cell centres [degree N].
!  *REAL*    *omask*      - land/ocean mask.
!
!******************************************************************************
  use mod_xc,         only: xcsum,xchalt,mnproc,nbdy,ips
  use mo_control_bgc, only: io_stdo_bgc,do_oalk,bgc_namelist,get_bgc_namelist
  use mod_dia,        only: iotype
  use mod_nctools,    only: ncfopn,ncgeti,ncfcls

  implicit none

  integer, intent(in) :: kpie,kpje
  real,    intent(in) :: pdlxp(kpie,kpje), pdlyp(kpie,kpje)
  real,    intent(in) :: pglat(1-nbdy:kpie+nbdy,1-nbdy:kpje+nbdy)
  real,    intent(in) :: omask(kpie,kpje)

  integer :: i,j,errstat
  logical :: file_exists=.false.
  integer :: iounit
  real    :: avflx,ztotarea
  real    :: ztmp1(1-nbdy:kpie+nbdy,1-nbdy:kpje+nbdy)

  namelist /bgcoafx/ oalkscen,oalkfile,addalk,cdrmip_latmax,cdrmip_latmin,    &
       &             ramp_start,ramp_end

  ! Read parameters for alkalinization fluxes from namelist file
  if(.not. allocated(bgc_namelist)) call get_bgc_namelist
  open (newunit=iounit, file=bgc_namelist, status='old'                   &
       &   ,action='read')
  read (unit=iounit, nml=BGCOAFX)
  close (unit=iounit)

  ! Return if alkalinization is turned off
  if (.not. do_oalk) then
    if (mnproc.eq.1) then
      write(io_stdo_bgc,*) ''
      write(io_stdo_bgc,*) 'ini_read_oafx: ocean alkalinization is not activated.'
    endif
    return
  end if

  ! Initialise the module
  if(.not. lini) then 

    if(mnproc.eq.1) then
      write(io_stdo_bgc,*)' '
      write(io_stdo_bgc,*)'***************************************************'
      write(io_stdo_bgc,*)'iHAMOCC: Initialization of module mo_read_oafx:'
      write(io_stdo_bgc,*)' '
    endif

    if( trim(oalkscen)=='const' .or. trim(oalkscen)=='ramp' .or.              &
        trim(oalkscen)=='file' ) then

      if(mnproc.eq.1) then
        write(io_stdo_bgc,*)'Using alkalinization scenario ', trim(oalkscen)
        if( trim(oalkscen)=='file' ) then
          write(io_stdo_bgc,*) 'from ', trim(oalkfile)
        endif
        write(io_stdo_bgc,*)' '
      endif

      if( trim(oalkscen)=='file' ) then
        ! Check if OA file exists. If not, abort.
        inquire(file=oalkfile,exist=file_exists)
        if (.not. file_exists .and. mnproc.eq.1) then
          write(io_stdo_bgc,*) ''
          write(io_stdo_bgc,*) 'ini_read_oafx: Cannot find ocean alkalinization file... '
          call xchalt('(ini_read_oafx)')
          stop '(ini_read_oafx)'
        endif
      endif

      ! Allocate field to hold alkalinization fluxes
      if(mnproc.eq.1) then
        write(io_stdo_bgc,*)'Memory allocation for variable oalkflx ...'
        write(io_stdo_bgc,*)'First dimension    : ',kpie
        write(io_stdo_bgc,*)'Second dimension   : ',kpje
      endif
   
      allocate(oalkflx(kpie,kpje),stat=errstat)
      if(errstat.ne.0) stop 'not enough memory oalkflx'
      oalkflx(:,:) = 0.0

      if( trim(oalkscen)=='file' ) then

        ! read start and end year of OA file
        call ncfopn(trim(oalkfile),'r',' ',1,iotype)
        call ncgeti('startyear',startyear)
        call ncgeti('endyear',endyear)
        call ncfcls
    
      else

        ! Calculate total ocean area 
        ztmp1(:,:)=0.0
        do j=1,kpje
        do i=1,kpie
          if( omask(i,j).gt.0.5 .and. pglat(i,j)<cdrmip_latmax                  &
                                .and. pglat(i,j)>cdrmip_latmin ) then
            ztmp1(i,j)=ztmp1(i,j)+pdlxp(i,j)*pdlyp(i,j)
          endif
        enddo
        enddo
  
        call xcsum(ztotarea,ztmp1,ips)
        
        ! Calculate alkalinity flux (kmol m^2 yr-1) to be applied
        avflx = addalk/ztotarea*Pmol2kmol
        if(mnproc.eq.1) then
          write(io_stdo_bgc,*)' '
          write(io_stdo_bgc,*)' applying alkalinity flux of ', avflx, ' kmol m-2 yr-1'
          write(io_stdo_bgc,*)'             over an area of ', ztotarea , ' m2'
          if( trim(oalkscen)=='ramp' ) then
            write(io_stdo_bgc,*)'             ramping-up from ', ramp_start, ' to ', ramp_end
          endif
        endif
  
        do j=1,kpje
        do i=1,kpie
          if( omask(i,j).gt.0.5 .and. pglat(i,j)<cdrmip_latmax                  &
                                .and. pglat(i,j)>cdrmip_latmin ) then
            oalkflx(i,j) = avflx
          endif
        enddo
        enddo

      endif

      lini=.true.

    !--------------------------------
    ! No valid scenario specified
    !--------------------------------
    else
    
      write(io_stdo_bgc,*) ''
      write(io_stdo_bgc,*) 'ini_read_oafx: invalid alkalinization scenario'
      call xchalt('(ini_read_oafx)')
      stop '(ini_read_oafx)' 
      
    endif

  endif ! not lini


!******************************************************************************
end subroutine ini_read_oafx


subroutine get_oafx(kpie,kpje,kplyear,kplmon,omask,oafx)
!******************************************************************************
!
!     J. Schwinger            *NORCE Climate, Bergen*     2021-11-15
!
! Purpose
! -------
!  -return ocean alkalinization flux.
!
! Changes: 
! --------
!
!
! Parameter list:
! ---------------
!  *INTEGER*   *kpie*    - 1st dimension of model grid.
!  *INTEGER*   *kpje*    - 2nd dimension of model grid.
!  *INTEGER*   *kplyear* - current year.
!  *INTEGER*   *kplmon*  - current month.
!  *REAL*      *omask*   - land/ocean mask (1=ocean)
!  *REAL*      *oaflx*   - alkalinization flux [kmol m-2 yr-1]
!
!******************************************************************************
  use mod_xc,         only: xchalt,mnproc
  use netcdf,         only: nf90_open,nf90_close,nf90_nowrite
  use mo_control_bgc, only: io_stdo_bgc,do_oalk
  use mod_time,       only: nday_of_year

  implicit none

  integer, intent(in)  :: kpie,kpje,kplyear,kplmon
  real,    intent(in)  :: omask(kpie,kpje)
  real,    intent(out) :: oafx(kpie,kpje)

  ! local variables
  integer              :: month_in_file,ncstat,ncid,current_day
  integer, save        :: oldmonth=0 

  if (.not. do_oalk) then
    oafx(:,:) = 0.0
    return 
  endif
  
  !--------------------------------
  ! Scenarios of constant fluxes
  !--------------------------------
  if( trim(oalkscen)=='const' ) then
      
    oafx(:,:) = oalkflx(:,:)

  !--------------------------------
  ! Scenario of ramping-up fluxes
  !--------------------------------
  elseif(trim(oalkscen)=='ramp' ) then

    if(kplyear.lt.ramp_start ) then
      oafx(:,:) = 0.0
    elseif(kplyear.ge.ramp_end ) then
      oafx(:,:) = oalkflx(:,:)
    else
      current_day = (kplyear-ramp_start)*365+nday_of_year
      oafx(:,:) = oalkflx(:,:) * current_day / ((ramp_end-ramp_start)*365.)
    endif

  !--------------------------------
  ! Scenario from OA file
  !--------------------------------
  elseif(trim(oalkscen)=='file' ) then

    ! read OA data from file
    if (kplmon.ne.oldmonth) then
      month_in_file=(max(startyear,min(endyear,kplyear))-startyear)*12+kplmon
      if (mnproc.eq.1) then
        write(io_stdo_bgc,*) 'Read OA month ',month_in_file, &
                             'from file ',trim(oalkfile)
      endif
      ncstat=nf90_open(trim(oalkfile),nf90_nowrite,ncid)
      call read_netcdf_var(ncid,'oafx',oalkflx,1,month_in_file,0)
      ncstat=nf90_close(ncid)
      oldmonth=kplmon
    endif
    oafx(:,:) = oalkflx

  else
    
    write(io_stdo_bgc,*) ''
    write(io_stdo_bgc,*) 'get_oafx: invalid alkalinization scenario... '
    call xchalt('(get_oafx)')
    stop '(get_oafx)' 
      
  endif

!******************************************************************************
end subroutine get_oafx



!******************************************************************************
end module mo_read_oafx
