import os
import urllib.parse
import urllib.request


def is_valid_file(file_name):
    if file_name.endswith('.csv'):
        print("Error. Remove file extension and try again")
        return False

    elif not os.path.exists(file_name + '.csv'):
        print("Error. File does not exist. Check your path")
        return False

    return True


def display_inserted(result):
    print('----------------------------------------------------------------\n')
    print('        --------    TRANSACTIONS SUMMARY        --------        \n')
    print('----------------------------------------------------------------\n')
    print("There are {0}  successfully inserted records\n".format(len(result)))
    print('================================================================\n')
    if len(result) <= 0:
        print("No record was inserted\n")
    else:
        print('{0} \t{1} \t '.format('Line No.', 'Description'))
        print('------------------------------------------------------------\n')
        for item in result:
            print('{0}\t{1}'.format(item[1], item[0]))


def display_skipped(result):
    print('----------------------------------------------------------------\n')
    print('There are {0}  skipped records \n'.format(len(result)))
    print('===============================================================\n')
    if len(result) <= 0:
        print('No record was skipped \n')
    else:
        print('{0} \t{1} \t {2}'.format('Line No.', 'Description',
                                        'Error Message'))
        print('------------------------------------------------------------\n')
        for key, value in result.items():

            print('{0}\t \t{1} \t{2}'.format(value[1], key, value[0]))


def is_valid_url(url):
    """
    checks if url is valid
    :param url: url
    :return: boolean
    """
    parsed_url = urllib.parse.urlparse(url)

    if parsed_url.scheme and parsed_url.netloc:
        return True

    print('Please enter a valid url.')
    return False


def get_csv_from_url(url):
    """
    Get csv from URL
    :param url: url that points to csv file
    :return: None or file object
    """
    filename = 'temp.csv'
    try:
        res = urllib.request.urlopen(url)
    except (urllib.error.HTTPError, urllib.error.HTTPError):
        print('There was an error processing your request')
        return None

    if 'csv' in res.getheader('content-type'):
        f = open(filename, 'wb')
        f.write(res.read())
        f.close()
        return filename

    print('The url does not point to a valid a csv file')
    return None
