#!/bin/sh
#SBATCH --job-name=APC
#SBATCH --output=%j.o
#SBATCH --error=%j.e
##SBATCH --mail-type=END
##SBATCH --mail-user=hf2583nyu.edu
#SBATCH --time=2-20:00:00
#SBATCH --nodes=1
#SBATCH --mem=100GB
#SBATCH -p argon
##SBATCH -w gpu7
#SBATCH -c 28
##SBATCH --gres=gpu:1
##SBATCH --constraint=g6230|2630v4

#load amber20z module automatically according to gpu model
module purge
export MODULEPATH=$MODULEPATH:/gpfsnyu/xspace/sungroup/modules
if [ "$SLURM_JOB_NODELIST" == "gpu7" ];then
# for 2080Ti, load avx512_cuda11.02 version
module load amber/20z
elif [ "$SLURM_JOB_NODELIST" == "gpu6" ];then
# for P100, load avx2_cuda11.02 version
module load amber/20z_avx2
elif [ "$SLURM_JOB_NODELIST" == "agpu8" ];then
# for 2080Ti, load avx512_cuda11.02 version
module load amber/20z
elif [ "$SLURM_JOB_NODELIST" == "argpu1" ];then
# for 3080Ti, load avx512_cuda11.02 version
module load amber/20gpu
else
# for K10, load avx2_cuda10.2 version
module load amber/20z_avx2_cuda10.2
fi

HQDIR=/gpfsnyu/xspace/projects/APC/MDinput
SYSTEM=2v8a_
JOBDIR=/gpfsnyu/xspace/projects/APC/2v8a
TOP=2v8a.prmtop
ID_NO=65
START=1
STOP=50
min_inputfile=min.in
heat_inputfile=heat.in
npt_eq_inputfile=npt_eq_fixed_solute.in

INIT_CONFIG=2v8a.inpcrd
TRAJDIR=/gpfsnyu/xspace/projects/APC/2v8a/MD
min=yes
run_on_tmp=yes
heat=yes
eq_npt=yes
md_control=pmemd
NT=28
#mkdir $tmp
#cd $tmp
#cp $TRAJDIR/*relax*rst  $tmp
mkdir -p $TRAJDIR
cd $TRAJDIR
# before we start with everything else, create a directory 

if [ "$run_on_tmp" == "yes" ];then
        echo Calculation were performed on tmp directory on computation node
        echo NOTE: if job failure happen make sure you clean up any cookie crumble of your calculation may left on the computation node. 
        TEMPDIR=/tmp/${SLURM_JOB_USER}_${SLURM_JOB_ID}
        mkdir $TEMPDIR
        cd $TEMPDIR
else
        echo Calculation were performed on current node
        echo NOTE: Make sure that this calculation is not heavy one that read and write frequently otherwise this job might influence cluster performance.
fi

#############################################################################


if [ "$min" == "yes" ];then
echo Starting Energy Minimization... `date`
MIN_DIR=${TRAJDIR}/1_min
mkdir -p $MIN_DIR
###[1] minimization run
#        mpirun  pmemd.cuda -O -i ${HQDIR}/${min_inputfile} \
       mpirun -np ${NT} ${md_control}.MPI -O -i ${HQDIR}/${min_inputfile} \
           -o min.out \
           -p ${JOBDIR}/${TOP} \
           -c ${JOBDIR}/${INIT_CONFIG} -ref ${JOBDIR}/${INIT_CONFIG} \
           -r min.rst \
           -inf min.mdinfo
echo Job minimization finished on `date`
else
        echo WARNING: No minimization were performed. 
fi
cp min.rst        $MIN_DIR
cp min.mdinfo     $MIN_DIR
cp min.out        $MIN_DIR

###########################################################################

if [ "$heat" == "yes" ];then
echo Start Heating ... `date`
## [2] heat
HEAT_DIR=${TRAJDIR}/2_heat
mkdir -p $HEAT_DIR
       mpirun -np ${NT} ${md_control}.MPI -O -i ${HQDIR}/${heat_inputfile} \
           -o heat.out \
           -p ${JOBDIR}/${TOP} \
           -c min.rst -ref min.rst \
           -r heat.rst \
           -x heat.mdcrd.nc \
           -inf heat.mdinfo

echo Job heat finished on `date`
else
        echo WARNING: Proper heating to target temperature were not performed.
fi
cp heat.rst        $HEAT_DIR
cp heat.mdinfo     $HEAT_DIR
cp heat.out        $HEAT_DIR
cp heat.mdcrd.nc   $HEAT_DIR

############################################################################

if [ "$eq_npt" == "yes" ];then
echo Starting NPT Equilibration ... `date`
### [3] 1 ns NPT equilibriation
NPT_DIR=${TRAJDIR}/3_NPT
mkdir -p $NPT_DIR
       mpirun -np ${NT} ${md_control}.MPI -O -i ${HQDIR}/${npt_eq_inputfile} \
           -o equil_NPT.out \
           -p ${JOBDIR}/${TOP} \
           -c heat.rst -ref heat.rst \
           -r equil_NPT.rst \
           -x equil_NPT.mdcrd.nc \
           -inf equil_NPT.mdinfo

echo Job NPT_eq finished on `date`
else
        echo WARNING: No NPT equilibration were performed.
fi


cp equil_NPT.rst        $NPT_DIR
cp equil_NPT.mdinfo     $NPT_DIR
cp equil_NPT.out        $NPT_DIR
cp equil_NPT.mdcrd.nc   $NPT_DIR

############################################################################
# remove temp dir on the computational node as good habit 
rm -r $TEMPDIR

