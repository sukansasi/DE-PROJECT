import boto3
from botocore.exceptions import ClientError


def find_most_recent_filename(table_name, bucket_name, file_type="json"):
    """
    This function:
    - looks through files (of default json type, or parquet type if specified) in a specified s3 bucket, with a specified table name
    - selects the most recent file starting with this table name
    - compares the date/time in this file with the date/time in the last_updated.txt
    - if date/time are the same, returns string of the filename
    - else raises Exception informing the user that there is no new data for this table since the last update
    These functionalities are implemented using dependency injection.

    Arguments: table_name (str): a specified table name from the original OLTP database

    Returns: if a new file is found in the specified bucket containing the specified table_name,
    returns a string containing that file's name, otherwise raises an appropriate exception.

    """
    files = find_files_with_specified_table_name(table_name, bucket_name)
    most_recent_file = find_most_recent_file(files, table_name, bucket_name, file_type)
    return most_recent_file


"""The below functions are used as dependencies, injected within find_most_recent_filename:"""


def find_files_with_specified_table_name(table_name, bucket_name):
    """
    This function:
    - Retrieves a list of files in a specified s3 bucket (bucket_name) whose names contain the specified table_name

    Arguments:
    - table_name (str): name contained within the name of the file you're searching for
    - bucket_name (str): the name of the s3 bucket you're searching in

    Returns:
    - list[str]: A list of filenames in the s3 bucket containing table_name
    """
    s3 = boto3.resource("s3")
    bucket = s3.Bucket(bucket_name)
    files = []
    for obj in bucket.objects.filter(Prefix=table_name):
        if "" not in obj.key.split("/"):
            files.append(obj.key.split("/")[1])
    return files


def find_most_recent_file(files, table_name, bucket_name, filetype="json"):
    """
    This function:
    - returns the name of the most recent file in a given s3 bucket whose name contains table_name

    Arguments:
    - files (List[str]): list of filenames
    - table_name (str): name contained within the name of the file you're searching for
    - bucket_name (str): the name of the s3 bucket you're searching in

    Returns:
    - str: The name of the most recent file whose name contains table_name

    """
    try:
        most_recent_file = sorted(files, reverse=True)[0]
        if filetype == "json":
            file_date_time = most_recent_file[len(table_name) + 1 : -5]
        elif filetype == "parquet":
            file_date_time = most_recent_file[
                len(table_name) + 1 : -8
            ]  # Removes ".parquet"# Get only "2025-05-29T11:06"
            # file_date_time = file_datetime_full[:16]  # Get only "2025-05-29T11:06"

        s3 = boto3.resource("s3")
        last_updated_file = s3.Object(bucket_name, "last_updated.txt")
        last_update = last_updated_file.get()["Body"].read().decode("utf-8").strip()
        print(f"last_update: {last_update}")
        print(f"file_date: {file_date_time}")

        if last_update == file_date_time:
            return most_recent_file
        else:
            print(f"No new data for table, {table_name}")
            return None
    except IndexError:
        raise IndexError(
            f"No file containing table, {table_name} is found in the s3 bucket"
        )
    except ClientError as err:
        if (
            err.response["Error"]["Code"] == "404"
            or err.response["Error"]["Code"] == "NoSuchKey"
        ):
            raise FileNotFoundError(
                "File not found 404: there is no last_updated.txt file saved in the s3 bucket 'fscifa-raw-data'"
            )
        else:
            raise ClientError
