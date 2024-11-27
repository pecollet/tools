# NMT timeline plotter tool

This tool draws a timeline chart of Java Native Memory usage. It shows memory usage per category.

## pre-requisites
 * setup a venv
 * Install the python requirements into your venv with `pip install -r requirements.txt`

## Usage

`python3 nmt_parser.py --fromdir some/path/to/input/directory [--stacked] [--value {committed,reserved}`

### options

 * `--fromdir <dir>` : path to a directory containing the NMT report files
 * `--stacked` : flag to indicate that the plot should be a stacked area chart. Otherwise it's a simple line chart. Defaults to false.
 * `--value {committed,reserved}`` : choose to display the value of the reserved memory or the committed memory. Defaults to reserved.

### output
PNG files are wrtten to an `output` subdirectory within the input directory.
A CSV file with the parsed data is also generated.


## Notes

 * Parsing of the file name, from which the timestamp is extracted, seems to vary quite a lot and may require a custom implementation. 
 * The script supports the extraction of hostnames from the file name. In that case it will generate a chart per host.