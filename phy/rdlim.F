! ------------------------------------------------------------------------------
! Copyright (C) 2008-2022 Mats Bentsen, Mehmet Ilicak, Ingo Bethke,
!                         Ping-Gin Chiu, Aleksi Nummelin
!
! This file is part of BLOM.
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
! along with BLOM. If not, see <https://www.gnu.org/licenses/>.
! ------------------------------------------------------------------------------

      subroutine rdlim
c
c --- ------------------------------------------------------------------
c --- Read limits file
c --- ------------------------------------------------------------------
c
      use mod_config, only: expcnf, runid, inst_suffix
      use mod_constants, only: epsilt
      use mod_calendar, only: date_type, daynum_diff, calendar_errstr,
     .                        operator(==), operator(<), operator(/=)
      use mod_time, only: date0, date, nday1, nday2, nstep0, nstep1,
     .                    nstep2, nstep, lstep, nstep_in_day, time0,
     .                    time, baclin, batrop, init_timevars,
     .                    set_day_of_year, step_time
      use mod_xc
      use mod_grid, only: grfile
      use mod_eos, only: pref
      use mod_inicon, only: icfile
      use mod_advect, only: rmpmth
      use mod_pbcor, only: bmcmth
      use mod_momtum, only: mdv2hi, mdv2lo, mdv4hi, mdv4lo, mdc2hi,
     .                      mdc2lo, vsc2hi, vsc2lo, vsc4hi, vsc4lo,
     .                      cbar, cb, mommth
      use mod_barotp, only: cwbdts, cwbdls
      use mod_forcing, only: aptflx, apsflx, ditflx, disflx, scfile,
     .                       trxday, srxday, trxdpt, srxdpt, trxlim,
     .                       srxlim, srxbal, sprfac
      use mod_swabs, only: swamth, jwtype, chlopt, ccfile
      use mod_diffusion, only: readnml_diffusion
      use mod_mxlayr, only: rm0, rm5, ce, mlrttp
      use mod_niw, only: niwgf, niwbf, niwlf
      use mod_tidaldissip, only: tdfile
      use mod_dia
      use mod_ben02, only: atm_path, atm_path_len
      use mod_vcoord, only: vcoord_type_tag, isopyc_bulkml,
     .                      cntiso_hybrid, readnml_vcoord
      use mod_cesm, only: runid_cesm, ocn_cpl_dt_cesm, nstep_in_cpl,
     .                    smtfrc
      use mod_pointtest, only: itest, jtest
      use mod_budget, only: cnsvdi
      use mod_checksum, only: csdiag
c
      implicit none
c
      type(date_type) :: date0_rest
      character(len = 256) :: nlfnm,runtyp,rstfnm
      logical :: fexist
      integer :: m,n,idate,idate0,ios
c
      namelist /limits/ nday1,nday2,idate,idate0,runid,expcnf,runtyp,
     .  grfile,icfile,pref,baclin,batrop,
     .  mdv2hi,mdv2lo,mdv4hi,mdv4lo,mdc2hi,mdc2lo,
     .  vsc2hi,vsc2lo,vsc4hi,vsc4lo,cbar,cb,cwbdts,cwbdls,
     .  mommth,bmcmth,rmpmth,mlrttp,
     .  rm0,rm5,ce,tdfile,niwgf,niwbf,niwlf,
     .  swamth,jwtype,chlopt,ccfile,
     .  trxday,srxday,trxdpt,srxdpt,trxlim,srxlim,
     .  aptflx,apsflx,ditflx,disflx,srxbal,scfile,smtfrc,sprfac,
     .  atm_path,
     .  itest,jtest,
     .  cnsvdi,
     .  csdiag,
     .  rstfrq,rstfmt,rstcmp,iotype
c
c --- read limits namelist
c
      if (mnproc.eq.1) then
c
        nlfnm='ocn_in'//trim(inst_suffix)
        inquire(file=nlfnm,exist=fexist)
        if (fexist) then
          open (unit=nfu,file=nlfnm,status='old',action='read',recl=80)
        else
          nlfnm='limits'//trim(inst_suffix)
          inquire(file=nlfnm,exist=fexist)
          if (fexist) then
            open (unit=nfu,file=nlfnm,status='old',action='read',
     .            recl=80)
          else
            write (lp,*) 'rdlim: could not find namelist file!'
            call xchalt('(rdlim)')
                   stop '(rdlim)'
          endif
        endif
        read (unit=nfu,nml=LIMITS)
        close (unit=nfu)
c
c --- - print limits namelist to stdout 
        write (lp,*)
        write (lp,*) 'rdlim: BLOM LIMITS NAMELIST GROUP:' 
        write (lp,*) 'NDAY1',NDAY1
        write (lp,*) 'NDAY2',NDAY2
        write (lp,*) 'IDATE',IDATE
        write (lp,*) 'IDATE0',IDATE0
        write (lp,*) 'RUNID ',trim(RUNID)
        write (lp,*) 'EXPCNF ',trim(EXPCNF)
        write (lp,*) 'RUNTYP ',trim(RUNTYP)
        write (lp,*) 'GRFILE ',trim(GRFILE)
        write (lp,*) 'ICFILE ',trim(ICFILE)
        write (lp,*) 'PREF',PREF
        write (lp,*) 'BACLIN',BACLIN
        write (lp,*) 'BATROP',BATROP
        write (lp,*) 'MDV2HI',MDV2HI
        write (lp,*) 'MDV2LO',MDV2LO
        write (lp,*) 'MDV4HI',MDV4HI
        write (lp,*) 'MDV4LO',MDV4LO
        write (lp,*) 'MDC2HI',MDC2HI
        write (lp,*) 'MDC2LO',MDC2LO
        write (lp,*) 'VSC2HI',VSC2HI
        write (lp,*) 'VSC2LO',VSC2LO
        write (lp,*) 'VSC4HI',VSC4HI
        write (lp,*) 'VSC4LO',VSC4LO
        write (lp,*) 'CBAR',CBAR
        write (lp,*) 'CB',CB
        write (lp,*) 'CWBDTS',CWBDTS
        write (lp,*) 'CWBDLS',CWBDLS
        write (lp,*) 'MOMMTH ',trim(MOMMTH)
        write (lp,*) 'BMCMTH ',trim(BMCMTH)
        write (lp,*) 'RMPMTH ',trim(RMPMTH)
        write (lp,*) 'RM0',RM0
        write (lp,*) 'RM5',RM5
        write (lp,*) 'CE',CE
        write (lp,*) 'TDFILE',trim(TDFILE)
        write (lp,*) 'NIWGF',NIWGF
        write (lp,*) 'NIWBF',NIWBF
        write (lp,*) 'NIWLF',NIWLF
        write (lp,*) 'SWAMTH ',trim(SWAMTH)
        write (lp,*) 'JWTYPE',JWTYPE
        write (lp,*) 'CHLOPT ',trim(CHLOPT)
        write (lp,*) 'CCFILE ',trim(CCFILE)
        write (lp,*) 'TRXDAY',TRXDAY
        write (lp,*) 'SRXDAY',SRXDAY
        write (lp,*) 'TRXDPT',TRXDPT
        write (lp,*) 'SRXDPT',SRXDPT
        write (lp,*) 'TRXLIM',TRXLIM
        write (lp,*) 'SRXLIM',SRXLIM
        write (lp,*) 'APTFLX',APTFLX
        write (lp,*) 'APSFLX',APSFLX
        write (lp,*) 'DITFLX',DITFLX
        write (lp,*) 'DISFLX',DISFLX
        write (lp,*) 'SRXBAL',SRXBAL
        write (lp,*) 'SCFILE ',trim(SCFILE)
        write (lp,*) 'SMTFRC',SMTFRC
        write (lp,*) 'SPRFAC',SPRFAC
        write (lp,*) 'ATM_PATH ',trim(ATM_PATH)
        write (lp,*) 'ITEST',ITEST
        write (lp,*) 'JTEST',JTEST
        write (lp,*) 'CNSVDI',CNSVDI
        write (lp,*) 'CSDIAG',CSDIAG
        write (lp,*) 'RSTFRQ',RSTFRQ
        write (lp,*) 'RSTFMT',RSTFMT
        write (lp,*) 'RSTCMP',RSTCMP
        write (lp,*) 'IOTYPE',IOTYPE
        write (lp,*)
c
      endif
c
c --- broadcast variables set by limits namelist
c
      call xcbcst(nday1)
      call xcbcst(nday2)
      call xcbcst(idate)
      call xcbcst(idate0)
      call xcbcst(runid)
      call xcbcst(expcnf)
      call xcbcst(runtyp)
      call xcbcst(grfile)
      call xcbcst(icfile)
      call xcbcst(pref)
      call xcbcst(baclin)
      call xcbcst(batrop)
      call xcbcst(mdv2hi)
      call xcbcst(mdv2lo)
      call xcbcst(mdv4hi)
      call xcbcst(mdv4lo)
      call xcbcst(mdc2hi)
      call xcbcst(mdc2lo)
      call xcbcst(vsc2hi)
      call xcbcst(vsc2lo)
      call xcbcst(vsc4hi)
      call xcbcst(vsc4lo)
      call xcbcst(cbar)
      call xcbcst(cb)
      call xcbcst(cwbdts)
      call xcbcst(cwbdls)
      call xcbcst(mommth)
      call xcbcst(bmcmth)
      call xcbcst(rmpmth)
      call xcbcst(mlrttp)
      call xcbcst(rm0)
      call xcbcst(rm5)
      call xcbcst(ce)
      call xcbcst(tdfile)
      call xcbcst(niwgf)
      call xcbcst(niwbf)
      call xcbcst(niwlf)
      call xcbcst(swamth)
      call xcbcst(jwtype)
      call xcbcst(chlopt)
      call xcbcst(ccfile)
      call xcbcst(trxday)
      call xcbcst(srxday)
      call xcbcst(trxdpt)
      call xcbcst(srxdpt)
      call xcbcst(trxlim)
      call xcbcst(srxlim)
      call xcbcst(aptflx)
      call xcbcst(apsflx)
      call xcbcst(ditflx)
      call xcbcst(disflx)
      call xcbcst(srxbal)
      call xcbcst(scfile)
      call xcbcst(smtfrc)
      call xcbcst(sprfac)
      call xcbcst(atm_path)
      call xcbcst(itest)
      call xcbcst(jtest)
      call xcbcst(cnsvdi)
      call xcbcst(csdiag)
      call xcbcst(rstfrq)
      call xcbcst(rstfmt)
      call xcbcst(rstcmp)
      call xcbcst(iotype)
c
c --- read vertical coordinate namelist variables
      call readnml_vcoord
c
c --- read diffusion namelist variables
      call readnml_diffusion
c
c --- read diaphy namelist
c
      if (mnproc.eq.1) then
c
        GLB_AVEPERIO(:)=-999
        open (unit=nfu,file=nlfnm,status='old',action='read',recl=80)
        read (unit=nfu,nml=DIAPHY,iostat=ios)
        close (unit=nfu)
c
c --- - determine number of io groups
        nphy=0  
        do n=1,nphymax 
          if (GLB_AVEPERIO(n).ne.-999) nphy=nphy+1 
        enddo
c
c --- - modify diaphy namelist variables based on dependency with other
c --- - variables set in namelists
        select case (vcoord_type_tag)
          case (isopyc_bulkml)
            LYR_DIFVMO(1:nphy)=0
            LYR_DIFVHO(1:nphy)=0
            LYR_DIFVSO(1:nphy)=0
            LYR_UMFLSM(1:nphy)=0
            LYR_UTFLSM(1:nphy)=0
            LYR_USFLSM(1:nphy)=0
            LYR_VMFLSM(1:nphy)=0
            LYR_VTFLSM(1:nphy)=0
            LYR_VSFLSM(1:nphy)=0
            LVL_UMFLSM(1:nphy)=0
            LVL_UTFLSM(1:nphy)=0
            LVL_USFLSM(1:nphy)=0
            LVL_VMFLSM(1:nphy)=0
            LVL_VTFLSM(1:nphy)=0
            LVL_VSFLSM(1:nphy)=0
            MSC_MMFSML(1:nphy)=0
            MSC_MMFSMD(1:nphy)=0
            MSC_MHFSM (1:nphy)=0
            MSC_MSFSM (1:nphy)=0
            LVL_DIFVMO(1:nphy)=0
            LVL_DIFVHO(1:nphy)=0
            LVL_DIFVSO(1:nphy)=0
          case (cntiso_hybrid)
            H2D_IDKEDT(1:nphy)=0
            H2D_MTKEUS(1:nphy)=0
            H2D_MTKENI(1:nphy)=0
            H2D_MTKEBF(1:nphy)=0
            H2D_MTKERS(1:nphy)=0
            H2D_MTKEPE(1:nphy)=0
            H2D_MTKEKE(1:nphy)=0
            LYR_DIFDIA(1:nphy)=0
            LVL_DIFDIA(1:nphy)=0
          case default
            write (lp,*) 'rdlim: unsupported vertical coordinate!'
            call xcstop('(rdlim)')
                   stop '(rdlim)'
        end select
        if (trxday.eq.0.) then
          H2D_SURRLX(1:nphy)=0
        endif
        if (srxday.eq.0.) then
          H2D_SALRLX(1:nphy)=0
        endif
c
c --- - print diaphy namelist
        write (lp,*)
        write (lp,*) 'rdlim: BLOM DIAPHY NAMELIST GROUP:' 
        write (lp,*) 'GLB_FNAMETAG',GLB_FNAMETAG(1:nphy)
        write (lp,*) 'GLB_AVEPERIO',GLB_AVEPERIO(1:nphy)
        write (lp,*) 'GLB_FILEFREQ',GLB_FILEFREQ(1:nphy)
        write (lp,*) 'GLB_COMPFLAG',GLB_COMPFLAG(1:nphy)
        write (lp,*) 'GLB_NCFORMAT',GLB_NCFORMAT(1:nphy)
        write (lp,*) 'H2D_ABSWND  ',H2D_ABSWND(1:nphy)
        write (lp,*) 'H2D_ALB     ',H2D_ALB(1:nphy)
        write (lp,*) 'H2D_BTMSTR  ',H2D_BTMSTR(1:nphy)
        write (lp,*) 'H2D_BRNFLX  ',H2D_BRNFLX(1:nphy)
        write (lp,*) 'H2D_BRNPD   ',H2D_BRNPD(1:nphy)
        write (lp,*) 'H2D_DFL     ',H2D_DFL(1:nphy)
        write (lp,*) 'H2D_EVA     ',H2D_EVA(1:nphy)
        write (lp,*) 'H2D_FMLTFZ  ',H2D_FMLTFZ(1:nphy)
        write (lp,*) 'H2D_FICE    ',H2D_FICE(1:nphy)
        write (lp,*) 'H2D_HICE    ',H2D_HICE(1:nphy)
        write (lp,*) 'H2D_HMLTFZ  ',H2D_HMLTFZ(1:nphy)
        write (lp,*) 'H2D_HSNW    ',H2D_HSNW(1:nphy)
        write (lp,*) 'H2D_IAGE    ',H2D_IAGE(1:nphy)
        write (lp,*) 'H2D_IDKEDT  ',H2D_IDKEDT(1:nphy)
        write (lp,*) 'H2D_LIP     ',H2D_LIP(1:nphy)
        write (lp,*) 'H2D_MAXMLD  ',H2D_MAXMLD(1:nphy)
        write (lp,*) 'H2D_MLD     ',H2D_MLD(1:nphy)
        write (lp,*) 'H2D_MLTS    ',H2D_MLTS(1:nphy)
        write (lp,*) 'H2D_MLTSMN  ',H2D_MLTSMN(1:nphy)
        write (lp,*) 'H2D_MLTSMX  ',H2D_MLTSMX(1:nphy)
        write (lp,*) 'H2D_MLTSSQ  ',H2D_MLTSSQ(1:nphy)
        write (lp,*) 'H2D_MTKEUS  ',H2D_MTKEUS(1:nphy)
        write (lp,*) 'H2D_MTKENI  ',H2D_MTKENI(1:nphy)
        write (lp,*) 'H2D_MTKEBF  ',H2D_MTKEBF(1:nphy)
        write (lp,*) 'H2D_MTKERS  ',H2D_MTKERS(1:nphy)
        write (lp,*) 'H2D_MTKEPE  ',H2D_MTKEPE(1:nphy)
        write (lp,*) 'H2D_MTKEKE  ',H2D_MTKEKE(1:nphy)
        write (lp,*) 'H2D_MTY     ',H2D_MTY(1:nphy)
        write (lp,*) 'H2D_NSF     ',H2D_NSF(1:nphy)
        write (lp,*) 'H2D_PBOT    ',H2D_PBOT(1:nphy)
        write (lp,*) 'H2D_PSRF    ',H2D_PSRF(1:nphy)
        write (lp,*) 'H2D_RFIFLX  ',H2D_RFIFLX(1:nphy)
        write (lp,*) 'H2D_RNFFLX  ',H2D_RNFFLX(1:nphy)
        write (lp,*) 'H2D_SALFLX  ',H2D_SALFLX(1:nphy)
        write (lp,*) 'H2D_SALRLX  ',H2D_SALRLX(1:nphy)
        write (lp,*) 'H2D_SBOT    ',H2D_SBOT(1:nphy)
        write (lp,*) 'H2D_SEALV   ',H2D_SEALV(1:nphy)
        write (lp,*) 'H2D_SLVSQ   ',H2D_SLVSQ(1:nphy)
        write (lp,*) 'H2D_SFL     ',H2D_SFL(1:nphy)
        write (lp,*) 'H2D_SIGMX   ',H2D_SIGMX(1:nphy)
        write (lp,*) 'H2D_SOP     ',H2D_SOP(1:nphy)
        write (lp,*) 'H2D_SSS     ',H2D_SSS(1:nphy)
        write (lp,*) 'H2D_SSSSQ   ',H2D_SSSSQ(1:nphy)
        write (lp,*) 'H2D_SST     ',H2D_SST(1:nphy)
        write (lp,*) 'H2D_SSTSQ   ',H2D_SSTSQ(1:nphy)
        write (lp,*) 'H2D_SURFLX  ',H2D_SURFLX(1:nphy)
        write (lp,*) 'H2D_SURRLX  ',H2D_SURRLX(1:nphy)
        write (lp,*) 'H2D_SWA     ',H2D_SWA(1:nphy)
        write (lp,*) 'H2D_T20D    ',H2D_T20D(1:nphy)
        write (lp,*) 'H2D_TAUX    ',H2D_TAUX(1:nphy)
        write (lp,*) 'H2D_TAUY    ',H2D_TAUY(1:nphy)
        write (lp,*) 'H2D_TBOT    ',H2D_TBOT(1:nphy)
        write (lp,*) 'H2D_TICE    ',H2D_TICE(1:nphy)
        write (lp,*) 'H2D_TSRF    ',H2D_TSRF(1:nphy)
        write (lp,*) 'H2D_UB      ',H2D_UB(1:nphy)
        write (lp,*) 'H2D_UICE    ',H2D_UICE(1:nphy)
        write (lp,*) 'H2D_USTAR   ',H2D_USTAR(1:nphy)
        write (lp,*) 'H2D_USTAR3  ',H2D_USTAR3(1:nphy)
        write (lp,*) 'H2D_VB      ',H2D_VB(1:nphy)
        write (lp,*) 'H2D_VICE    ',H2D_VICE(1:nphy)
        write (lp,*) 'H2D_ZTX     ',H2D_ZTX(1:nphy)
        write (lp,*) 'LYR_BFSQ    ',LYR_BFSQ(1:nphy)
        write (lp,*) 'LYR_DIFDIA  ',LYR_DIFDIA(1:nphy)
        write (lp,*) 'LYR_DIFVMO  ',LYR_DIFVMO(1:nphy)
        write (lp,*) 'LYR_DIFVHO  ',LYR_DIFVHO(1:nphy)
        write (lp,*) 'LYR_DIFVSO  ',LYR_DIFVSO(1:nphy)
        write (lp,*) 'LYR_DIFINT  ',LYR_DIFINT(1:nphy)
        write (lp,*) 'LYR_DIFISO  ',LYR_DIFISO(1:nphy)
        write (lp,*) 'LYR_DP      ',LYR_DP(1:nphy)
        write (lp,*) 'LYR_DPU     ',LYR_DPU(1:nphy)
        write (lp,*) 'LYR_DPV     ',LYR_DPV(1:nphy)
        write (lp,*) 'LYR_DZ      ',LYR_DZ(1:nphy)
        write (lp,*) 'LYR_SALN    ',LYR_SALN(1:nphy)
        write (lp,*) 'LYR_TEMP    ',LYR_TEMP(1:nphy)
        write (lp,*) 'LYR_TRC     ',LYR_TRC(1:nphy)
        write (lp,*) 'LYR_UFLX    ',LYR_UFLX(1:nphy)
        write (lp,*) 'LYR_UTFLX   ',LYR_UTFLX(1:nphy)
        write (lp,*) 'LYR_USFLX   ',LYR_USFLX(1:nphy)
        write (lp,*) 'LYR_UMFLTD  ',LYR_UMFLTD(1:nphy)
        write (lp,*) 'LYR_UMFLSM  ',LYR_UMFLSM(1:nphy)
        write (lp,*) 'LYR_UTFLTD  ',LYR_UTFLTD(1:nphy)
        write (lp,*) 'LYR_UTFLSM  ',LYR_UTFLSM(1:nphy)
        write (lp,*) 'LYR_UTFLLD  ',LYR_UTFLLD(1:nphy)
        write (lp,*) 'LYR_USFLTD  ',LYR_USFLTD(1:nphy)
        write (lp,*) 'LYR_USFLSM  ',LYR_USFLSM(1:nphy)
        write (lp,*) 'LYR_USFLLD  ',LYR_USFLLD(1:nphy)
        write (lp,*) 'LYR_UVEL    ',LYR_UVEL(1:nphy)
        write (lp,*) 'LYR_VFLX    ',LYR_VFLX(1:nphy)
        write (lp,*) 'LYR_VTFLX   ',LYR_VTFLX(1:nphy)
        write (lp,*) 'LYR_VSFLX   ',LYR_VSFLX(1:nphy)
        write (lp,*) 'LYR_VMFLTD  ',LYR_VMFLTD(1:nphy)
        write (lp,*) 'LYR_USFLSM  ',LYR_USFLSM(1:nphy)
        write (lp,*) 'LYR_VTFLTD  ',LYR_VTFLTD(1:nphy)
        write (lp,*) 'LYR_VTFLSM  ',LYR_VTFLSM(1:nphy)
        write (lp,*) 'LYR_VTFLLD  ',LYR_VTFLLD(1:nphy)
        write (lp,*) 'LYR_VSFLTD  ',LYR_VSFLTD(1:nphy)
        write (lp,*) 'LYR_VSFLSM  ',LYR_VSFLSM(1:nphy)
        write (lp,*) 'LYR_VSFLLD  ',LYR_VSFLLD(1:nphy)
        write (lp,*) 'LYR_VVEL    ',LYR_VVEL(1:nphy)
        write (lp,*) 'LYR_WFLX    ',LYR_WFLX(1:nphy)
        write (lp,*) 'LYR_WFLX2   ',LYR_WFLX2(1:nphy)
        write (lp,*) 'LYR_PV      ',LYR_PV(1:nphy)
        write (lp,*) 'LYR_TKE     ',LYR_TKE(1:nphy)
        write (lp,*) 'LYR_GLS_PSI ',LYR_GLS_PSI(1:nphy)
        write (lp,*) 'LYR_IDLAGE  ',LYR_IDLAGE(1:nphy)
        write (lp,*) 'LVL_BFSQ    ',LVL_BFSQ(1:nphy)
        write (lp,*) 'LVL_DIFDIA  ',LVL_DIFDIA(1:nphy)
        write (lp,*) 'LVL_DIFVMO  ',LVL_DIFVMO(1:nphy)
        write (lp,*) 'LVL_DIFVHO  ',LVL_DIFVHO(1:nphy)
        write (lp,*) 'LVL_DIFVSO  ',LVL_DIFVSO(1:nphy)
        write (lp,*) 'LVL_DIFINT  ',LVL_DIFINT(1:nphy)
        write (lp,*) 'LVL_DIFISO  ',LVL_DIFISO(1:nphy)
        write (lp,*) 'LVL_DIFISO  ',LVL_DIFISO(1:nphy)
        write (lp,*) 'LVL_DZ      ',LVL_DZ(1:nphy)
        write (lp,*) 'LVL_SALN    ',LVL_SALN(1:nphy)
        write (lp,*) 'LVL_TEMP    ',LVL_TEMP(1:nphy)
        write (lp,*) 'LVL_TRC     ',LVL_TRC(1:nphy)
        write (lp,*) 'LVL_UFLX    ',LVL_UFLX(1:nphy)
        write (lp,*) 'LVL_UTFLX   ',LVL_UTFLX(1:nphy)
        write (lp,*) 'LVL_USFLX   ',LVL_USFLX(1:nphy)
        write (lp,*) 'LVL_UMFLTD  ',LVL_UMFLTD(1:nphy)
        write (lp,*) 'LVL_UMFLSM  ',LVL_UMFLSM(1:nphy)
        write (lp,*) 'LVL_UTFLTD  ',LVL_UTFLTD(1:nphy)
        write (lp,*) 'LVL_UTFLSM  ',LVL_UTFLSM(1:nphy)
        write (lp,*) 'LVL_UTFLLD  ',LVL_UTFLLD(1:nphy)
        write (lp,*) 'LVL_USFLTD  ',LVL_USFLTD(1:nphy)
        write (lp,*) 'LVL_USFLSM  ',LVL_USFLSM(1:nphy)
        write (lp,*) 'LVL_USFLLD  ',LVL_USFLLD(1:nphy)
        write (lp,*) 'LVL_UVEL    ',LVL_UVEL(1:nphy)
        write (lp,*) 'LVL_VFLX    ',LVL_VFLX(1:nphy)
        write (lp,*) 'LVL_VTFLX   ',LVL_VTFLX(1:nphy)
        write (lp,*) 'LVL_VSFLX   ',LVL_VSFLX(1:nphy)
        write (lp,*) 'LVL_VMFLTD  ',LVL_VMFLTD(1:nphy)
        write (lp,*) 'LVL_VMFLSM  ',LVL_VMFLSM(1:nphy)
        write (lp,*) 'LVL_VTFLTD  ',LVL_VTFLTD(1:nphy)
        write (lp,*) 'LVL_VTFLSM  ',LVL_VTFLSM(1:nphy)
        write (lp,*) 'LVL_VTFLLD  ',LVL_VTFLLD(1:nphy)
        write (lp,*) 'LVL_VSFLTD  ',LVL_VSFLTD(1:nphy)
        write (lp,*) 'LVL_VSFLSM  ',LVL_VSFLSM(1:nphy)
        write (lp,*) 'LVL_VSFLLD  ',LVL_VSFLLD(1:nphy)
        write (lp,*) 'LVL_VVEL    ',LVL_VVEL(1:nphy)
        write (lp,*) 'LVL_WFLX    ',LVL_WFLX(1:nphy)
        write (lp,*) 'LVL_WFLX2   ',LVL_WFLX2(1:nphy)
        write (lp,*) 'LVL_PV      ',LVL_PV(1:nphy)
        write (lp,*) 'LVL_TKE     ',LVL_TKE(1:nphy)
        write (lp,*) 'LVL_GLS_PSI ',LVL_GLS_PSI(1:nphy)
        write (lp,*) 'LVL_IDLAGE  ',LVL_IDLAGE(1:nphy)
        write (lp,*) 'MSC_MMFLXL  ',MSC_MMFLXL(1:nphy)
        write (lp,*) 'MSC_MMFLXD  ',MSC_MMFLXD(1:nphy)
        write (lp,*) 'MSC_MMFTDL  ',MSC_MMFTDL(1:nphy)
        write (lp,*) 'MSC_MMFSML  ',MSC_MMFSML(1:nphy)
        write (lp,*) 'MSC_MMFTDD  ',MSC_MMFTDD(1:nphy)
        write (lp,*) 'MSC_MMFSMD  ',MSC_MMFSMD(1:nphy)
        write (lp,*) 'MSC_MHFLX   ',MSC_MHFLX(1:nphy)
        write (lp,*) 'MSC_MHFTD   ',MSC_MHFTD(1:nphy)
        write (lp,*) 'MSC_MHFSM   ',MSC_MHFSM(1:nphy)
        write (lp,*) 'MSC_MHFLD   ',MSC_MHFLD(1:nphy)
        write (lp,*) 'MSC_MSFLX   ',MSC_MSFLX(1:nphy)
        write (lp,*) 'MSC_MSFTD   ',MSC_MSFTD(1:nphy)
        write (lp,*) 'MSC_MSFSM   ',MSC_MSFSM(1:nphy)
        write (lp,*) 'MSC_MSFLD   ',MSC_MSFLD(1:nphy)
        write (lp,*) 'MSC_VOLTR   ',MSC_VOLTR(1:nphy)
        write (lp,*) 'MSC_MASSGS  ',MSC_MASSGS(1:nphy)
        write (lp,*) 'MSC_VOLGS   ',MSC_VOLGS(1:nphy)
        write (lp,*) 'MSC_SALNGA  ',MSC_SALNGA(1:nphy)
        write (lp,*) 'MSC_TEMPGA  ',MSC_TEMPGA(1:nphy)
        write (lp,*) 'MSC_SSSGA   ',MSC_SSSGA(1:nphy)
        write (lp,*) 'MSC_SSTGA   ',MSC_SSTGA(1:nphy)
        write (lp,*)
c
      endif
c
c --- broadcast variables set by diaphy namelist
c
      call xcbcst(H2D_ABSWND)
      call xcbcst(H2D_ALB)
      call xcbcst(H2D_BTMSTR)
      call xcbcst(H2D_BRNFLX)
      call xcbcst(H2D_BRNPD)
      call xcbcst(H2D_DFL)
      call xcbcst(H2D_EVA)
      call xcbcst(H2D_FICE)
      call xcbcst(H2D_FMLTFZ)
      call xcbcst(H2D_HICE)
      call xcbcst(H2D_HMLTFZ)
      call xcbcst(H2D_HSNW)
      call xcbcst(H2D_IAGE)
      call xcbcst(H2D_IDKEDT)
      call xcbcst(H2D_LIP)
      call xcbcst(H2D_MAXMLD)
      call xcbcst(H2D_MLD)
      call xcbcst(H2D_MLTS)
      call xcbcst(H2D_MLTSMN)
      call xcbcst(H2D_MLTSMX)
      call xcbcst(H2D_MLTSSQ)
      call xcbcst(H2D_MTKEUS)
      call xcbcst(H2D_MTKENI)
      call xcbcst(H2D_MTKEBF)
      call xcbcst(H2D_MTKERS)
      call xcbcst(H2D_MTKEPE)
      call xcbcst(H2D_MTKEKE)
      call xcbcst(H2D_MTY)
      call xcbcst(H2D_NSF)
      call xcbcst(H2D_PBOT)
      call xcbcst(H2D_PSRF)
      call xcbcst(H2D_RFIFLX)
      call xcbcst(H2D_RNFFLX)
      call xcbcst(H2D_SALFLX)
      call xcbcst(H2D_SALRLX)
      call xcbcst(H2D_SBOT)
      call xcbcst(H2D_SEALV)
      call xcbcst(H2D_SLVSQ)
      call xcbcst(H2D_SFL)
      call xcbcst(H2D_SOP)
      call xcbcst(H2D_SIGMX)
      call xcbcst(H2D_SSS)
      call xcbcst(H2D_SSSSQ)
      call xcbcst(H2D_SST)
      call xcbcst(H2D_SSTSQ)
      call xcbcst(H2D_SURFLX)
      call xcbcst(H2D_SURRLX)
      call xcbcst(H2D_SWA)
      call xcbcst(H2D_T20D)
      call xcbcst(H2D_TAUX)
      call xcbcst(H2D_TAUY)
      call xcbcst(H2D_TBOT)
      call xcbcst(H2D_TICE)
      call xcbcst(H2D_TSRF)
      call xcbcst(H2D_UB)
      call xcbcst(H2D_UICE)
      call xcbcst(H2D_USTAR)
      call xcbcst(H2D_USTAR3)
      call xcbcst(H2D_VB)
      call xcbcst(H2D_VICE)
      call xcbcst(H2D_ZTX)
      call xcbcst(LYR_BFSQ)
      call xcbcst(LYR_DIFDIA)
      call xcbcst(LYR_DIFVMO)
      call xcbcst(LYR_DIFVHO)
      call xcbcst(LYR_DIFVSO)
      call xcbcst(LYR_DIFINT)
      call xcbcst(LYR_DIFISO)
      call xcbcst(LYR_DP)
      call xcbcst(LYR_DPU)
      call xcbcst(LYR_DPV)
      call xcbcst(LYR_DZ)
      call xcbcst(LYR_SALN)
      call xcbcst(LYR_TEMP)
      call xcbcst(LYR_TRC)
      call xcbcst(LYR_UFLX)
      call xcbcst(LYR_UTFLX)
      call xcbcst(LYR_USFLX)
      call xcbcst(LYR_UMFLTD)
      call xcbcst(LYR_UMFLSM)
      call xcbcst(LYR_UTFLTD)
      call xcbcst(LYR_UTFLSM)
      call xcbcst(LYR_UTFLLD)
      call xcbcst(LYR_USFLTD)
      call xcbcst(LYR_USFLSM)
      call xcbcst(LYR_USFLLD)
      call xcbcst(LYR_UVEL)
      call xcbcst(LYR_VFLX)
      call xcbcst(LYR_VTFLX)
      call xcbcst(LYR_VSFLX)
      call xcbcst(LYR_VMFLTD)
      call xcbcst(LYR_VMFLSM)
      call xcbcst(LYR_VTFLTD)
      call xcbcst(LYR_VTFLSM)
      call xcbcst(LYR_VTFLLD)
      call xcbcst(LYR_VSFLTD)
      call xcbcst(LYR_VSFLSM)
      call xcbcst(LYR_VSFLLD)
      call xcbcst(LYR_VVEL)
      call xcbcst(LYR_WFLX)
      call xcbcst(LYR_WFLX2)
      call xcbcst(LYR_PV)
      call xcbcst(LYR_TKE)
      call xcbcst(LYR_GLS_PSI)
      call xcbcst(LYR_IDLAGE)
      call xcbcst(LVL_BFSQ)
      call xcbcst(LVL_DIFDIA)
      call xcbcst(LVL_DIFVMO)
      call xcbcst(LVL_DIFVHO)
      call xcbcst(LVL_DIFVSO)
      call xcbcst(LVL_DIFINT)
      call xcbcst(LVL_DIFISO)
      call xcbcst(LVL_DZ)
      call xcbcst(LVL_SALN)
      call xcbcst(LVL_TEMP)
      call xcbcst(LVL_TRC)
      call xcbcst(LVL_UFLX)
      call xcbcst(LVL_UTFLX)
      call xcbcst(LVL_USFLX)
      call xcbcst(LVL_UMFLTD)
      call xcbcst(LVL_UMFLSM)
      call xcbcst(LVL_UTFLTD)
      call xcbcst(LVL_UTFLSM)
      call xcbcst(LVL_UTFLLD)
      call xcbcst(LVL_USFLTD)
      call xcbcst(LVL_USFLSM)
      call xcbcst(LVL_USFLLD)
      call xcbcst(LVL_UVEL)
      call xcbcst(LVL_VFLX)
      call xcbcst(LVL_VTFLX)
      call xcbcst(LVL_VSFLX)
      call xcbcst(LVL_VMFLTD)
      call xcbcst(LVL_VMFLSM)
      call xcbcst(LVL_VTFLTD)
      call xcbcst(LVL_VTFLSM)
      call xcbcst(LVL_VTFLLD)
      call xcbcst(LVL_VSFLTD)
      call xcbcst(LVL_VSFLSM)
      call xcbcst(LVL_VSFLLD)
      call xcbcst(LVL_VVEL)
      call xcbcst(LVL_WFLX)
      call xcbcst(LVL_WFLX2)
      call xcbcst(LVL_PV)
      call xcbcst(LVL_TKE)
      call xcbcst(LVL_GLS_PSI)
      call xcbcst(LVL_IDLAGE)
      call xcbcst(MSC_MMFLXL)
      call xcbcst(MSC_MMFLXD)
      call xcbcst(MSC_MMFTDL)
      call xcbcst(MSC_MMFSML)
      call xcbcst(MSC_MMFTDD)
      call xcbcst(MSC_MMFSMD)
      call xcbcst(MSC_MHFLX)
      call xcbcst(MSC_MHFTD)
      call xcbcst(MSC_MHFSM)
      call xcbcst(MSC_MHFLD)
      call xcbcst(MSC_MSFLX)
      call xcbcst(MSC_MSFTD)
      call xcbcst(MSC_MSFSM)
      call xcbcst(MSC_MSFLD)
      call xcbcst(MSC_VOLTR)
      call xcbcst(MSC_MASSGS)
      call xcbcst(MSC_VOLGS)
      call xcbcst(MSC_SALNGA)
      call xcbcst(MSC_TEMPGA)
      call xcbcst(MSC_SSSGA)
      call xcbcst(MSC_SSTGA)
      call xcbcst(GLB_AVEPERIO)
      call xcbcst(GLB_FILEFREQ)
      call xcbcst(GLB_COMPFLAG)
      call xcbcst(GLB_NCFORMAT)
      do n=1,nphymax 
        call xcbcst(GLB_FNAMETAG(n))
      enddo
c
      call xcbcst(nphy)
c
c --- read merdia namelist if needed
c
      if (sum(MSC_MMFLXL(1:nphy)+MSC_MMFLXD(1:nphy)+MSC_MMFTDL(1:nphy)
     .       +MSC_MMFSML(1:nphy)+MSC_MMFTDD(1:nphy)+MSC_MMFSMD(1:nphy)
     .       +MSC_MHFLX (1:nphy)+MSC_MHFTD (1:nphy)+MSC_MHFSM (1:nphy)
     .       +MSC_MHFLD (1:nphy)+MSC_MSFLX (1:nphy)+MSC_MSFTD (1:nphy)
     .       +MSC_MSFSM (1:nphy)+MSC_MSFLD (1:nphy)).ne.0) then
c
        if (mnproc.eq.1) then
c
          open (unit=nfu,file=nlfnm,status='old',action='read',recl=80)
          read (unit=nfu,nml=MERDIA,iostat=ios)
          close (unit=nfu)
          if (ios.ne.0) then
            write (lp,*) 'rdlim: mertra namelist required!'
            call xchalt('(rdlim)')
                   stop '(rdlim)'
          endif
c
c --- --- determine number of regions for meridional overturning and
c --- --- flux diagnostics and print namelist
          mer_nreg=1
          do while (mer_regnam(mer_nreg).ne.'')
            mer_nreg=mer_nreg+1
            if (mer_nreg.gt.odm) exit
          enddo
          mer_nreg=mer_nreg-1
c
          do m=1,mer_nreg
            mer_nflg(m)=1
            do while (mer_regflg(m,mer_nflg(m)).ne.-1)
              mer_nflg(m)=mer_nflg(m)+1
              if (mer_nflg(m).gt.rflgdm) exit
            enddo
            mer_nflg(m)=mer_nflg(m)-1
          enddo
c
          write (lp,*)
          write (lp,*) 'rdlim: BLOM MERDIA NAMELIST GROUP:'
          write (lp,*) 'MER_ORFILE ',trim(mer_orfile)
          write (lp,*) 'MER_MIFILE ',trim(mer_mifile)
          do m=1,mer_nreg
            write (lp,*)
            write (lp,*) 'MER_REGNAM ',trim(mer_regnam(m))
            write (lp,*) 'MER_MINLAT ',mer_minlat(m)
            write (lp,*) 'MER_MAXLAT ',mer_maxlat(m)
            write (lp,*) 'MER_REGFLG ',(mer_regflg(m,n),n=1,mer_nflg(m))
          enddo
c
        endif
c
        call xcbcst(mer_nreg)
        do m=1,mer_nreg
          call xcbcst(mer_regnam(m))
        enddo
c
      endif
c
c --- read secdia namelist if needed
c
      if (sum(MSC_VOLTR(1:nphy)).ne.0) then
c
        if (mnproc.eq.1) then
c
          open (unit=nfu,file=nlfnm,status='old',action='read',recl=80)
          read (unit=nfu,nml=SECDIA,iostat=ios)
          close (unit=nfu)
          if (ios.ne.0) then
            write (lp,*) 'rdlim: sectra namelist required!'
            call xchalt('(rdlim)')
                   stop '(rdlim)'
          endif
c
          write (lp,*)
          write (lp,*) 'rdlim: BLOM SECDIA NAMELIST GROUP:'
          write (lp,*) 'SEC_SIFILE ',trim(sec_sifile)
c
        endif
c
      endif
c
c --- convert integer dates 
      date%year=sign(abs(idate)/10000,idate)
      date%month=abs(idate)/100-abs(date%year)*100
      date%day=abs(idate)-abs(date%year)*10000-date%month*100
      date0%year=sign(abs(idate0)/10000,idate0)
      date0%month=abs(idate0)/100-abs(date0%year)*100
      date0%day=abs(idate0)-abs(date0%year)*10000-date0%month*100
c
c --- set atm_path length
      if (expcnf.eq.'ben02syn'.or.expcnf.eq.'ben02clim'.or.
     .    expcnf.eq.'single_column') then
        atm_path_len=1
        do while (atm_path_len.lt.80.and.
     .            atm_path(atm_path_len:atm_path_len).ne.' ')
          atm_path_len=atm_path_len+1
        enddo
        atm_path_len=atm_path_len-1
      endif
c
c --- initialize time variables
      call init_timevars
c
      if (expcnf.eq.'cesm') then
c
c --- - override namelist experiment id with the one received from
c --- - coupler
        runid=runid_cesm
c
c --- - verify integer number of baroclinic time steps per coupling
c --- - interval
        if (mod(ocn_cpl_dt_cesm+epsilt,baclin).gt.2.*epsilt) then
          if (mnproc.eq.1) then
            write (lp,*) 'rdlim: must have an integer number of '//
     .                   'baroclinic time steps in a coupling'
            write (lp,*) '       interval!'
          endif
          call xcstop('(rdlim)')
                 stop '(rdlim)'
        endif
c
c --- - get time step and correct model date after first coupling
c --- - interval
        nstep_in_cpl=nint(ocn_cpl_dt_cesm/baclin)
        if (mnproc.eq.1) then
          write (lp,*) 'rdlim: number of baroclinic time steps in a '//
     .                 'coupling interval:',nstep_in_cpl
        endif
        nstep=0
        time0=0.
        do
          call step_time
          if (nstep.eq.nstep_in_cpl) exit
        enddo
        nstep0=nstep_in_cpl
c
        if (runtyp.eq.'startup') then
c
c --- --- when runtyp equal 'startup' the ocean integration start after
c --- --- first coupling interval
c
          nday1=0
          nstep1=nstep0
c
        else
c
c --- --- for runtyp equal 'hybrid', 'branch' or 'continue' a
c --- --- 'rpointer.ocn' file containing the path to a valid restart
c --- --- file is expected and integration time is retrieved from
c --- --- restart file
c
          if (mnproc.eq.1)
     .      inquire(file='rpointer.ocn'//trim(inst_suffix),exist=fexist)
          call xcbcst(fexist)
          if (.not.fexist) then
            if (mnproc.eq.1) then
              write (lp,*) 'rdlim: could not find rpointer.ocn file!'
            endif
            call xcstop('(rdlim)')
                   stop '(rdlim)'
          endif
          if (mnproc.eq.1) then
            open (unit=nfu,file='rpointer.ocn'//trim(inst_suffix))
            read (nfu,'(a)') rstfnm
            close (unit=nfu)
            inquire(file=rstfnm,exist=fexist)
          endif
          call xcbcst(fexist)
          if (.not.fexist) then
            if (mnproc.eq.1) then
              write (lp,*) 'rdlim: could not find restart file!'
            endif
            call xcstop('(rdlim)')
                   stop '(rdlim)'
          endif
          call xcbcst(rstfnm)
          call ncfopn(rstfnm,'r',' ',1,iotype)
          call ncgeti('nday0',date0_rest%day)
          call ncgeti('nmonth0',date0_rest%month)
          call ncgeti('nyear0',date0_rest%year)
          call ncgetr('time0',time0)
          call ncgetr('time',time)
          nday1=nint(time-time0)
c
          if (runtyp.eq.'hybrid') then
c 
c --- ----- When runtyp equal 'hybrid' the ocean integration starts
c --- ----- after first coupling interval.
            n=1
            do while (n.lt.256.and.rstfnm(n:n).ne.' ')
              n=n+1
            enddo
            n=n-1
            read (rstfnm(n-18:n-15),'(i4)') date%year
            read (rstfnm(n-13:n-12),'(i2)') date%month
            read (rstfnm(n-10:n-9 ),'(i2)') date%day
            if (date == date0) then
              date0=date0_rest
              nstep1=nday1*nstep_in_day+nstep0
            else
              time0=time
              nday1=0
              nstep1=nstep0
              date=date0
            endif
c
          else
c
            date0=date0_rest
            nstep1=nday1*nstep_in_day
c
c --- ----- For runtypes 'branch' or 'continue' override namelist date
c --- ----- with date extracted from restart file name
c
            n=1
            do while (n.lt.256.and.rstfnm(n:n).ne.' ')
              n=n+1
            enddo
            n=n-1
            read (rstfnm(n-18:n-15),'(i4)') date%year
            read (rstfnm(n-13:n-12),'(i2)') date%month
            read (rstfnm(n-10:n-9 ),'(i2)') date%day
            call set_day_of_year
c
          endif
c
          call ncfcls
c
        endif
c
c --- - Last time step number of current integration, 'nstep2' is not
c --- - used when coupled to CESM.
        nstep2=nstep1
c
      else
c
        if (nday1.lt.0.or.nday2.lt.0) then
          if (mnproc.eq.1) then
            write (lp,*) 'rdlim: integrations days must be positive!'
          endif
          call xcstop('(rdlim)')
                 stop '(rdlim)'
        endif
c
        if (nday2.lt.nday1) then
          if (mnproc.eq.1) then
            write (lp,*) 'rdlim: first day of integration must be '//
     .                   'less than or equal to last day!'
          endif
          call xcstop('(rdlim)')
                 stop '(rdlim)'
        endif
c
        if (nday1 == 0 .and. date /= date0) then
          if (mnproc.eq.1) then
            write (lp,*) 'rdlim: when first integration day is zero, '//
     .                   'model date and initial '
            write (lp,*) '       experiment date must be equal!'
          endif
          call xcstop('(rdlim)')
                 stop '(rdlim)'
        endif
c
        if (date < date0) then
          if (mnproc.eq.1) then
            write (lp,*) 'rdlim: model date must be greater or equal '//
     .                   'to initial experiment date!'
          endif
          call xcstop('(rdlim)')
                 stop '(rdlim)'
        endif
c
c --- - model is to be integrated from time step 'nstep1' to 'nstep2'
        time0=0.
        nstep0=0
        nstep1=nday1*nstep_in_day
        nstep2=nday2*nstep_in_day
c
        if (csdiag) then
          nstep2=nstep1+5
        endif
c
      endif
c
      if (trxday.eq.0.and.ditflx) then
        if (mnproc.eq.1) then
          write (lp,*)
     .      'rdlim: trxday=0. and ditflx=.true.. Inconsistent!'
        endif
        call xcstop('(rdlim)')
               stop '(rdlim)'
      endif
c
      if (srxday.eq.0.and.disflx) then
        if (mnproc.eq.1) then
          write (lp,*)
     .      'rdlim: srxday=0. and disflx=.true.. Inconsistent!'
        endif
        call xcstop('(rdlim)')
               stop '(rdlim)'
      endif
c
c --- represent time between restarts in time steps
      rstmon=.false.
      rstann=.false.
      if (nint(rstfrq).eq.30) then
        rstmon=.true.
      elseif (nint(rstfrq).ge.360.and.nint(rstfrq).le.366) then
        rstann=.true.
      endif
      rstfrq=nstep_in_day*max(1.,rstfrq)
c
c --- represent time between diagnostics in time steps
      do n=1,nphy 
        GLB_FILEFREQ(n)=max(GLB_AVEPERIO(n),GLB_FILEFREQ(n))
c
        if (GLB_AVEPERIO(n).lt.0) then
          diagfq_phy(n)=-real(nstep_in_day)/GLB_AVEPERIO(n)
        else
          diagfq_phy(n)=nstep_in_day*max(1,GLB_AVEPERIO(n))
        endif
        diagmon_phy(n)=.false.
        diagann_phy(n)=.false.
        if (GLB_AVEPERIO(n).eq.30) then
          diagmon_phy(n)=.true.
        elseif (GLB_AVEPERIO(n).ge.360.and.GLB_AVEPERIO(n).le.366) then
          diagann_phy(n)=.true.
        endif
c
        if (GLB_FILEFREQ(n).lt.0) then
          filefq_phy(n)=-real(nstep_in_day)/GLB_FILEFREQ(n)
        else
          filefq_phy(n)=nstep_in_day*max(1,GLB_FILEFREQ(n))
        endif
        filemon_phy(n)=.false.
        fileann_phy(n)=.false.
        if (GLB_FILEFREQ(n).eq.30) then
          filemon_phy(n)=.true.
        elseif (GLB_FILEFREQ(n).ge.360.and.GLB_FILEFREQ(n).le.366) then
          fileann_phy(n)=.true.
        endif
      enddo
c
      if (mnproc.eq.1) then
        write (lp,*)
        write (lp,*) 'rdlim: resolved parameters:'
        write (lp,'(a,i10)') ' nday1:                          ',nday1
        write (lp,'(a,i10)') ' nday2:                          ',nday2
        write (lp,'(a,i4.4,a,i2.2,a,i2.2,a,i5.5)')
     .    ' nyear ,nmonth ,nday ,nsec :     ',
     .     date%year ,' ,',date%month ,' ,',date%day ,' ,',
     .     nint(mod(nstep1,nstep_in_day)*baclin)
        write (lp,'(a,i4.4,a,i2.2,a,i2.2,a,i5.5)')
     .    ' nyear0,nmonth0,nday0,nsec0:     ',
     .     date0%year,' ,',date0%month,' ,',date0%day,' ,',0
        write (lp,'(a,i10)') ' barotr. steps per barocl. step: ',lstep
        write (lp,'(2a)') ' runid:                          ',
     .    trim(runid)
        write (lp,'(a,i10)') ' rstfrq:                         ',
     .    nint(rstfrq/nstep_in_day)
        write (lp,'(a,l10)') ' rstmon:                         ',rstmon
        write (lp,'(a,l10)') ' rstann:                         ',rstann
        write (lp,*)
        call flush(lp)
      endif
c
      return
      end
