import os
import re

files_with_hardcoded = set()

regex = re.compile(r"""(Text\(\s*\'[^\$\']*\'\s*\)|Text\(\s*\"[^\$\"]*\"\s*\)|labelText:\s*\'[^\']*\'|hintText:\s*\'[^\']*\')""")

for root, _, files in os.walk('lib'):
    for file in files:
        if file.endswith('.dart'):
            filepath = os.path.join(root, file)
            with open(filepath, 'r') as f:
                content = f.read()
                matches = regex.findall(content)
                if matches:
                    # Filter out purely empty or single character or just punctuation
                    real_matches = []
                    for m in matches:
                        inner = re.sub(r'Text\(|labelText:|hintText:|\'|\"|\)', '', m).strip()
                        if len(inner) > 2 and re.search('[a-zA-Z]', inner):
                            real_matches.append(inner)
                    if real_matches:
                        files_with_hardcoded.add(filepath)
                        # print(f"{filepath}: {real_matches}")

for path in sorted(files_with_hardcoded):
    print(path)

