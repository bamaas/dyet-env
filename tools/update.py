from ruamel.yaml import YAML
import argparse
import sys
import os

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Update version of requirement in chart")
    parser.add_argument('-e', '--env', type=str, help="The environment", required=True)
    parser.add_argument('-a', '--application', type=str, help="The application to update", required=True)
    parser.add_argument('-v', '--version', type=str, help="Update to this version", required=True)
    args = vars(parser.parse_args())

    env = args['env']
    application = args['application']
    new_version = args['version']

    print(f"Setting application '{application}' to version '{new_version}'.")
    chart_fp = os.path.join(os.getcwd(), "env", env, application, "Chart.yaml")
    yaml = YAML()
    with open(chart_fp, 'r') as f:
        requirements_content = yaml.load(f.read())

        # Set new version
        dependencies = requirements_content['dependencies']
        for i, dep in enumerate(dependencies, 1):
            if dep['name'] == application:
                dep['version'] = new_version
                break
            if i == len(dependencies):
                raise Exception(f"Application '{application}' doesn't exist in the '{env}' environment.")

    # Write to file
    with open(chart_fp, 'w') as f:
        yaml.dump(requirements_content, f)