##
## A simple VMD/psfgen script to merge multi-frame PDB files into a single PDB 
## structure, as in the case of the large multi-frame Virus capsids provided
## at the RCSB PDB site.
##
## Usage:
##   source mergemultiframepdb.tcl
##   mol new myfavoritemultiframepdb.pdb
##   merge_multi_frame_structure top /tmp/myworkarea /my/final/filename
##
## Results will be written to /my/final/filename.psf and /my/final/filename.pdb
##
## This script was tested with the following file from the RCSB PDB site:
##  ftp://ftp.rcsb.org/pub/pdb/data/biounit/coordinates/divided/k4/1k4r.pdb1.gz
##
package require psfgen

# this is a hack, just to get the topology file
package require membrane


proc writeallframes { whichmol workdir } {
  set allsel [atomselect $whichmol "all"]
  for {set i 0} {$i < [molinfo $whichmol get numframes]} {incr i} {
    foreach chain [lsort -unique [$allsel get chain]] {
      set sel [atomselect $whichmol "chain $chain"]
      $sel frame $i
      set filename [format "%s/merge%04d.%s.pdb" $workdir $i $chain] 
      file delete $filename
      $sel writepdb $filename
      $sel delete
    }
  }
  $allsel delete
}


proc deleteworkarea { whichmol workdir } {
  set allsel [atomselect $whichmol "all"]
  for {set i 0} {$i < [molinfo $whichmol get numframes]} {incr i} {
    foreach chain [lsort -unique [$allsel get chain]] {
      set filename [format "%s/merge%04d.%s.pdb" $workdir $i $chain] 
      file delete $filename
    } 
  }
  $allsel delete
}


proc mergeallframes { workdir filename } {
  global env

  # this next line is a total hack, needs a permanent place to get this from
  # set topologyfile [format "%s/plugins/noarch/tcl/membrane1.2/top_all27_prot_lipid.inp" $env(VMDDIR)]
  set topologyfile [format "%s/top_all27_prot_lipid.inp" $env(MEMBRANEDIR)]

  psfcontext new  
  resetpsf
  topology $topologyfile
  pdbalias residue HIS HSD
  pdbalias residue NAG DUM

  set nseg 1
  foreach pdb [lsort [glob $workdir/merge*.pdb]] {
    set segid V$nseg 
    puts stdout "PDB: $pdb  $segid" 
    segment $segid { 
      first NONE
      last NONE
      pdb $pdb 
    } 
    coordpdb $pdb $segid
    incr nseg
  } 

  guesscoord

  set psffilename [format "%s.psf" $filename]
  set pdbfilename [format "%s.pdb" $filename]
  writepsf $psffilename
  writepdb $pdbfilename
}


proc merge_multi_frame_structure { whichmol workdir filename } {
  writeallframes $whichmol $workdir
  mergeallframes $workdir $filename
  deleteworkarea $whichmol $workdir
}



