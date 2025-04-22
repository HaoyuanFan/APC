#include <iostream>
#include <fstream>
#include <vector>
#include <netcdf.h>

#define NC_ERR 2  // Error handling

using namespace std;

// Function to read an AMBER restart file and extract atomic coordinates
vector<float> read_rst7(const string& filename, int& num_atoms) {
    ifstream file(filename);
    if (!file.is_open()) {
        cerr << "Error opening file: " << filename << endl;
        exit(1);
    }

    string line;
    vector<float> coordinates;

    // Skip first two lines (title + atom count)
    getline(file, line);
    file >> num_atoms;

    // Read atomic coordinates
    float x, y, z;
    while (file >> x >> y >> z) {
        coordinates.push_back(x);
        coordinates.push_back(y);
        coordinates.push_back(z);
    }

    file.close();
    return coordinates;
}

// Function to write NetCDF file
void write_netcdf(const string& nc_filename, const vector<vector<float>>& frames, int num_atoms) {
    int ncid, dim_time, dim_atoms, var_coords;
    size_t num_frames = frames.size();

    // Create NetCDF file
    if (nc_create(nc_filename.c_str(), NC_CLOBBER, &ncid)) {
        cerr << "Error creating NetCDF file!" << endl;
        exit(NC_ERR);
    }

    // Define dimensions
    nc_def_dim(ncid, "frame", num_frames, &dim_time);
    nc_def_dim(ncid, "atom", num_atoms, &dim_atoms);
    
    // Define variable for coordinates
    int dims[3] = {dim_time, dim_atoms, 3};
    nc_def_var(ncid, "coordinates", NC_FLOAT, 3, dims, &var_coords);

    // End define mode
    nc_enddef(ncid);

    // Write coordinate data
    for (size_t f = 0; f < num_frames; ++f) {
        size_t start[] = {f, 0, 0};
        size_t count[] = {1, (size_t)num_atoms, 3};
        nc_put_vara_float(ncid, var_coords, start, count, frames[f].data());
    }

    // Close file
    nc_close(ncid);
    cout << "Successfully wrote output.nc!" << endl;
}

int main() {
	int argc = 2;
	string argv[argc];

    vector<vector<float>> frames;
    int num_atoms = 0;

    // Read all restart files
    for (int i = 1; i < argc; i++) {
        int atoms;
        //argv[i] = "MD/7_NVE_prod/sample_different/2v8a__prod_NVE_" + to_string(i) + ".rst";
        argv[i] = "MD/1_min/min.rst";
        vector<float> coords = read_rst7(argv[i], atoms);
        cout << atoms << endl;
        // Ensure atom count consistency
        if (i == 1) {
            num_atoms = atoms;
        } else if (atoms != num_atoms) {
            cerr << "Error: Atom count mismatch between frames!" << endl;
            return 1;
        }

        frames.push_back(coords);
    }

    // Write to NetCDF
    write_netcdf("output.nc", frames, num_atoms);
    return 0;
}

