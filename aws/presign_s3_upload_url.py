#!/usr/bin/python3
import boto3
import sys
import getopt
import urllib.parse
from botocore.exceptions import ClientError


def create_presigned_url_expanded(client_method_name="put_object", method_parameters=None,
                                  expiration=604800, http_method="PUT"):
    """Generate a presigned URL to invoke an S3.Client method

    Not all the client methods provided in the AWS Python SDK are supported.

    :param client_method_name: Name of the S3.Client method, e.g., 'list_buckets'
    :param method_parameters: Dictionary of parameters to send to the method
    :param expiration: Time in seconds for the presigned URL to remain valid
    :param http_method: HTTP method to use (GET, etc.)
    :return: Presigned URL as string. If error, returns None.
    """

    # Generate a presigned URL for the S3 client method
    s3_client = boto3.client('s3')
    try:
        response = s3_client.generate_presigned_url(ClientMethod=client_method_name,
                                                    Params=method_parameters,
                                                    ExpiresIn=expiration,
                                                    HttpMethod=http_method)
    except ClientError as e:
        print("error:"+e)
        return None

    # The response contains the presigned URL
    return response

def usage():
    print('################################################################################################################')
    print('Description:')
    print(f'   Creates pre-signed AWS s3 upload URLs, and generates the associated curl upload commands.')
    print('################################################################################################################')
    print('Usage:')
    print('   python3', sys.argv[0],'-c <customer> [-n <count>] [-e <expirationDays>] [-b <s3bucket>] [-k <s3key>]')
    print('     -c, --customer     : customer name (default=ACME)') 
    print('     -n, --number       : specifies the number of upload URLs to generate (default=1)')
    print('     -e, --expiration   : URL expiration in days (default=7)') 
    print('     -b, --bucket       : bucket name (default=neo4j-customer-support)') 
    print('     -k, --key          : bucket key prefix (default=customers/healthchecks)') 
    print('     -h                 : help/usage') 
    print()
    print('   Pre-signed URLs created are for files at location s3://<bucket>/<bucket key prefix>/<customer name>/report_<i>.zip')
    print('################################################################################################################')
    print('Examples:')
    print(f'   - Support upload')
    print(f'        python3 {sys.argv[0]} -c 17999 -k customers')
    print(f'        => s3://neo4j-customer-support/customers/17999/report_1.zip')
    print(f'   - Uploads for a cluster Health Check')
    print(f'        python3 {sys.argv[0]} -c SomeBank -n 3')
    print(f'        => s3://neo4j-customer-support/customers/healthchecks/SomeBank/report_1.zip, report_2.zip & report_3.zip')

#defaults
# s3://neo4j-customer-support/customers/healthchecks/ACME/report_1.zip
bucket="neo4j-customer-support"
bucket_key_prefix="customers/healthchecks"
file_prefix="report"
customerName="ACME"
fileCount = 1
expirationDays = 7

#read command line parameters
try:   
    opts, args = getopt.getopt(sys.argv[1:],"hn:c:e:b:k:",["number=","customer=","expirationDays=","bucket=","key="])
except getopt.GetoptError:
    usage()
    sys.exit(2)
# print(opts)
# print(args)
for opt, arg in opts:
    # print(opt, arg)
    if opt == '-h':
        usage()
        sys.exit()
    elif opt in ("-b", "--bucket"):
        bucket = arg
    elif opt in ("-k", "--key"):
        bucket_key_prefix = arg
    elif opt in ("-n", "--number"):
        fileCount = arg
    elif opt in ("-c", "--customer"):
        customerName = arg
    elif opt in ("-e", "--expirationDays"):
        expirationDays = arg
print(f' - bucket path is "{bucket}/{bucket_key_prefix}/{file_prefix}".')
print(f' - customer name is "{customerName}".')
print(f' - {fileCount} file URL(s) will be generated.')
print(' - expiration is after', expirationDays,'day(s).')
exp=int(expirationDays)*24*3600

#create pre-signed URLs
s3 = boto3.resource('s3')
print('Share the following command(s) with the customer, so they can upload their "neo4j-admin report" file(s) :')
for i in range(int(fileCount)):
    fileName=file_prefix+"_"+str(i+1)

    safe_customerName = urllib.parse.quote_plus(customerName)
    result=create_presigned_url_expanded(method_parameters={"Bucket":bucket, "Key": bucket_key_prefix+"/"+safe_customerName+"/"+fileName+".zip"}, expiration=exp)

    if result is None:
        exit(1)  

    print(f'curl -k  -X PUT -T host{i+1}-YYYY-MM-DD_HHmmss.zip "{result}"')
