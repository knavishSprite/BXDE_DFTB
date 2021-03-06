!!* Container module for the Slater-Koster data
!!* @desc This module contains the Slater-Koster tables. It decides, which
!!* one to call for which species. It can be easily extended to contain
!!* different Slater-Koster schemes for different species. At the moment,
!!* it handles only Slater-Koster data tabulated on an equidistant grid.
module SlakoCont
#include "allocate.h"
#include "assert.h"  
  use Accuracy
  use SlakoEqGrid
  implicit none
  private

  public :: OSlakoCont, init, destruct
  public :: addTable, getMIntegrals, getCutoff, getSKIntegrals

  !!* Container for Slater-Koster integrals for all pair-interactions
  type OSlakoCont
    private
    type(PSlaKo_), pointer :: slakos(:,:)
    integer :: nSpecie
    integer :: mInt
    real(dp) :: cutoff
    logical :: tDataOK
    logical :: tInit = .false.
  end type OSlakoCont

  !! Pointer to a specific Slater-Koster table implementation.
  type PSlaKo_
    integer :: iType = 0
    type(OSlakoEqGrid), pointer :: pSlakoEqGrid => null()
  end type PSlaKo_

  
  !!* Initialises SlakoCont
  interface init
    module procedure SlakoCont_init
  end interface

  !!* Destroys the components of SlakoCont
  interface destruct
    module procedure SlakoCont_destruct
  end interface

  !!* Adds a Slater-Koster table for a given diatomic pair to the container.
  interface addTable
    module procedure SlakoCont_addTableEqGrid
  end interface

  !!* Returns the maximal number of integrals needed for the interactions.
  interface getMIntegrals
    module procedure SlakoCont_getMIntegrals
  end interface

  !!* Returns the cutoff for all interactions
  interface getCutoff
    module procedure SlakoCont_getCutoff
  end interface

  !!* Returns the Slater-Koster integrals for a given distance for a given
  !!* species pair.
  interface getSKIntegrals
    module procedure SlakoCont_getSKIntegrals
  end interface
  
contains

  !!* Initialises SlakoCont
  !!* @param self SlakoCont instance
  !!* @param nSpecie Nr. of species in the system.
  subroutine SlakoCont_init(self, nSpecie)
    type(OSlakoCont), intent(out) :: self
    integer, intent(in) :: nSpecie

    ASSERT(.not. self%tInit)

    self%nSpecie = nSpecie
    INITALLOCATE_PARR(self%slakos, (nSpecie, nSpecie))
    self%mInt = 0
    self%cutoff = 0.0_dp
    self%tDataOK = .false.
    self%tInit = .true.

  end subroutine SlakoCont_init

  
  
  !!* Destroys the components of SlakoCont
  !!* @param self SlakoCont instance
  subroutine SlakoCont_destruct(self)
    type(OSlakoCont), intent(inout) :: self

    DEALLOCATE_PARR(self%slakos)
    self%tInit = .false.
    self%tDataOK = .false.

  end subroutine SlakoCont_destruct



  !!* Adds a Slater-Koster table for a given diatomic pair to the container.
  !!* @param self SlakoCont instance
  !!* @param pTable Pointer to the Slater-Koster table to be added
  !!* @param iSp1 Index of the first interacting species
  !!* @param iSp2 Index of the second interacting species
  subroutine SlakoCont_addTableEqGrid(self, pTable, iSp1, iSp2)
    type(OSlakoCont), intent(inout) :: self
    type(OSlakoEqGrid), pointer :: pTable
    integer, intent(in) :: iSp1, iSp2

    ASSERT(self%tInit)
    self%slakos(iSp2, iSp1)%iType = 1
    self%slakos(iSp2, iSp1)%pSlakoEqGrid => pTable
    self%tDataOK = all(self%slakos(:,:)%iType /= 0)
    self%mInt = max(self%mInt, getNIntegrals(pTable))
    self%cutoff = max(self%cutoff, getCutoff(pTable))

  end subroutine SlakoCont_addTableEqGrid

  
  
  !!* Returns the maximal number of integrals needed for describing any of the
  !!* interactions in the container
  !!* @param self SlakoCont instance
  !!* @return Max. numberf of integrals.
  !!* @note This subroutine is "pure", so that it can be used to determine
  !!* the size of statical arrays.
  pure function SlakoCont_getMIntegrals(self) result(mInt)
    type(OSlakoCont), intent(in) :: self
    integer :: mInt

    !! Pure procedures can not contain any I/O, therefore the following
    !! assertion is commented out
    !ASSERT(self%tInit)
    mInt = self%mInt

  end function SlakoCont_getMIntegrals

  
  
  !!* Returns the cutoff for all interactions
  !!* @param self SlakoCont instance
  !!* @return Cutoff.
  function SlakoCont_getCutoff(self) result(cutoff)
    type(OSlakoCont), intent(in) :: self
    real(dp) :: cutoff

    ASSERT(self%tInit)
    cutoff = self%cutoff

  end function SlakoCont_getCutoff


  !!* Returns the Slater-Koster integrals for a given distance for a given
  !!* species pair.
  !!* @param self SlakoCont instance
  !!* @param sk Contains the integrals on exit
  !!* @param dist Distance of the two atoms
  !!* @param sp1 Index of the first interacting species.
  !!* @param sp2 Index of the second interacting species.
  subroutine SlakoCont_getSKIntegrals(self, sk, dist, sp1, sp2)
    type(OSlakoCont), intent(in) :: self
    real(dp), intent(out) :: sk(:)
    real(dp), intent(in) :: dist
    integer, intent(in) :: sp1, sp2

    ASSERT(self%tInit .and. self%tDataOK)
    call getSKIntegrals(self%slakos(sp2, sp1)%pSlakoEqGrid, sk, dist)

  end subroutine SlakoCont_getSKIntegrals

  
  
end module SlakoCont
