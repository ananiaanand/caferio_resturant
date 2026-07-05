import re

file_path = 'c:\\caferio_new\\caferio_app\\lib\\screens\\menu_screen.dart'

with open(file_path, 'r', encoding='utf-8') as f:
    content = f.read()

def replacer(match):
    id_val = int(match.group(1))
    cat = ""
    if 1 <= id_val <= 12:
        cat = 'Curries & Fries'
    elif 13 <= id_val <= 22:
        cat = 'Main Course'
    elif 23 <= id_val <= 31:
        cat = 'Non-Veg Sides'
    else:
        cat = 'Veg Chinese'
    
    return f"id: '{id_val}',\n      category: '{cat}',"

new_content = re.sub(r"id:\s*'(\d+)',", replacer, content)

with open(file_path, 'w', encoding='utf-8') as f:
    f.write(new_content)
print("Updated categories successfully.")
