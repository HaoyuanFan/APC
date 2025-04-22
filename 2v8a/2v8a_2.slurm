#!/bin/sh
#SBATCH --job-name=APC
#SBATCH --output=%j.o
#SBATCH --error=%j.e
##SBATCH --mail-type=END
##SBATCH --mail-user=hf2583@nyu.edu
#SBATCH --time=2-20:00:00
#SBATCH --nodes=1
#SBATCH --mem=100GB
#SBATCH -p argon
##SBATCH -w gpu7
#SBATCH -c 1
#SBATCH --gres=gpu:1
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
TOP_DIR=/gpfsnyu/xspace/projects/APC/2v8a
TOP=2v8a.prmtop
START=1
STOP=200
# input file name 
nvt_eq_inputfile=nvt_eq_fixed_solute.in # required by nvt equilibration 
nvt_sampling_inputfile=nvt_sampling_fixed_solute.in 
nve_prod_inputfile=nve_prod_fixed_solute_conv.in

TRAJDIR=/gpfsnyu/xspace/projects/APC/2v8a/MD

run_on_tmp=yes
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

## [3] 1 ns NPT simulation with CPU
# Ignore how to run it, 'cause it is in test1.slurm
# here, we define where to get its output files
NPT_equil_DIR=${TRAJDIR}/3_NPT
# copy the result of the NPT simulation to the temporary folder
cp ${NPT_equil_DIR}/equil_NPT.rst ${TEMPDIR}


## [4] 1 ns NVT equilibriation
# Since it is the first NVT trajectory, we marked it as 0
CONTINUE_FROM=0
# where to store the results
NVT_equil_DIR=${TRAJDIR}/4_NVT_relax/sample_different
mkdir -p $NVT_equil_DIR

echo Starting NVT Equilibration ... `date`

# run the cuda code on the computational node 
pmemd.cuda -O -i ${HQDIR}/${nvt_eq_inputfile} \
           -o ${SYSTEM}_NVT_${CONTINUE_FROM}.out \
           -p ${TOP_DIR}/${TOP} \
           -c equil_NPT.rst -ref equil_NPT.rst \
           -r ${SYSTEM}_NVT_${CONTINUE_FROM}.rst \
           -x ${SYSTEM}_NVT_${CONTINUE_FROM}.mdcrd.nc \
           -inf ${SYSTEM}_NVT_${CONTINUE_FROM}.mdinfo
cp ${SYSTEM}_NVT_${CONTINUE_FROM}.rst        $NVT_equil_DIR
cp ${SYSTEM}_NVT_${CONTINUE_FROM}.mdcrd.nc   $NVT_equil_DIR
cp ${SYSTEM}_NVT_${CONTINUE_FROM}.mdinfo     $NVT_equil_DIR
cp ${SYSTEM}_NVT_${CONTINUE_FROM}.out        $NVT_equil_DIR

echo Finished NVT equilibration run
echo 

# [5]  Run NVT sampling from equilibrated NVT 
NVT_sample_DIR=${TRAJDIR}/5_NVT_sample/sample_different
mkdir -p $NVT_sample_DIR
echo Starting NVT sampling from equilibrated NVT ... `date`
for  (( j = ${START}; j <= ${STOP}; j++)) 
do
beforej=$((j-1))
pmemd.cuda -O -i ${HQDIR}/${nvt_sampling_inputfile} \
           -o ${SYSTEM}_NVT_${j}.out \
           -p ${TOP_DIR}/${TOP} \
           -c ${SYSTEM}_NVT_${beforej}.rst -ref ${SYSTEM}_NVT_${beforej}.rst \
           -r ${SYSTEM}_NVT_${j}.rst \
           -x ${SYSTEM}_NVT_${j}.mdcrd.nc \
           -inf ${SYSTEM}_NVT_${j}.mdinfo
cp ${SYSTEM}_NVT_${j}.rst        $NVT_sample_DIR
cp ${SYSTEM}_NVT_${j}.mdcrd.nc   $NVT_sample_DIR
cp ${SYSTEM}_NVT_${j}.mdinfo     $NVT_sample_DIR
cp ${SYSTEM}_NVT_${j}.out        $NVT_sample_DIR
rm *.out* *.mdcrd* *.mdinfo
done
echo Finished all NVT sampling on  `date`
echo 

# [6]  Run NVE relaxation run
echo Starting NVE relaxation ... `date`
NVE_relax_DIR=${TRAJDIR}/6_NVE_relax/sample_different
mkdir -p $NVE_relax_DIR
nve_relax_inputfile=nve_relax_fixed_solute.in

for  (( j = ${START}; j <= ${STOP}; j++))
do
# copy the result of the canonical sampling to the temperory 
cp NVT_sample_DIR/${SYSTEM}_NVT_${j}.rst .

pmemd.cuda -O -i ${HQDIR}/${nve_relax_inputfile} \
           -o ${SYSTEM}_relax_NVE_${j}.out \
           -p ${TOP_DIR}/${TOP} \
           -c ${SYSTEM}_NVT_${j}.rst -ref ${SYSTEM}_NVT_${j}.rst \
           -r ${SYSTEM}_relax_NVE_${j}.rst \
           -x ${SYSTEM}_relax_NVE_${j}.mdcrd.nc \
           -inf ${SYSTEM}_relax_NVE_${j}.mdinfo
# to prevent memory overload move everything to job dir every timestep, leave only rst behind
cp ${SYSTEM}_relax_NVE_${j}.out      $NVE_relax_DIR
cp ${SYSTEM}_relax_NVE_${j}.rst      $NVE_relax_DIR
cp ${SYSTEM}_relax_NVE_${j}.mdinfo   $NVE_relax_DIR
cp ${SYSTEM}_relax_NVE_${j}.mdcrd.nc $NVE_relax_DIR
#${SYSTEM}_relax_NVE_${j}.rst 
rm ${SYSTEM}_relax_NVE_${j}.out ${SYSTEM}_relax_NVE_${j}.mdinfo  ${SYSTEM}_relax_NVE_${j}.mdcrd.nc
done 
echo Finished all NVE relaxation run on `date`
echo 

# [7] Run NVE production run
echo Starting NVE production ... `date`
NVE_prod_DIR=${TRAJDIR}/7_NVE_prod/sample_different
mkdir -p $NVE_prod_DIR
nve_prod_inputfile=nve_prod_fixed_solute.in
for  (( j = ${START}; j <= ${STOP}; j++))
do
pmemd.cuda -O -i ${HQDIR}/${nve_prod_inputfile} \
           -o ${SYSTEM}_prod_NVE_${j}.out \
           -p ${TOP_DIR}/${TOP} \
           -c ${SYSTEM}_relax_NVE_${j}.rst -ref ${SYSTEM}_relax_NVE_${j}.rst \
           -r ${SYSTEM}_prod_NVE_${j}.rst \
           -x ${SYSTEM}_prod_NVE_${j}.mdcrd.nc \
           -inf ${SYSTEM}_prod_NVE_${j}.mdinfo
# to prevent memory overload move everything to job dir every timestep, leave only rst behind
cp ${SYSTEM}_prod_NVE_${j}.rst       $NVE_prod_DIR
cp ${SYSTEM}_prod_NVE_${j}.mdcrd.nc  $NVE_prod_DIR
cp ${SYSTEM}_prod_NVE_${j}.mdinfo    $NVE_prod_DIR
cp ${SYSTEM}_prod_NVE_${j}.out       $NVE_prod_DIR
rm ${SYSTEM}_prod_NVE_${j}.out ${SYSTEM}_prod_NVE_${j}.mdinfo ${SYSTEM}_prod_NVE_${j}.mdcrd.nc
done
echo Finished all NVE production run on `date`
# remove temp dir on the computational node as good habit 
rm -r $TEMPDIR











