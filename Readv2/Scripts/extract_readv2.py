from dbfread import DBF
import csv, os

path = r'O:\GitHub\snomed-database-loader\Readv2\Scottish\V2'

# Load terms into a dict
print('Loading terms...')
terms = {}
for rec in DBF(os.path.join(path, 'Term.dbf'), encoding='latin-1'):
    terms[rec['TERMID']] = rec['TERM60'].strip()

# Load DESC to link CC (ReadCode) -> TERMID, prefer Preferred terms (TERMTYPE=P)
print('Loading descriptions...')
code_terms = {}
for rec in DBF(os.path.join(path, 'DESC.DBF'), encoding='latin-1'):
    cc = rec['CC']
    tid = rec['TERMID']
    ttype = rec['TERMTYPE']
    if cc not in code_terms or ttype == 'P':
        code_terms[cc] = (tid, ttype)

# Load concepts for status
print('Loading concepts...')
concepts = {}
for rec in DBF(os.path.join(path, 'CONCEPT.DBF'), encoding='latin-1'):
    concepts[rec['READCODE']] = rec['STATUS']

# Write output
outfile = r'O:\GitHub\snomed-database-loader\Readv2\Readv2_codes_full.csv'
print(f'Writing {len(code_terms)} code-term pairs...')
with open(outfile, 'w', newline='', encoding='utf-8') as f:
    w = csv.writer(f)
    w.writerow(['ReadCode', 'TermID', 'PreferredTerm', 'Status'])
    for cc in sorted(code_terms.keys()):
        tid, ttype = code_terms[cc]
        term = terms.get(tid, '')
        status = concepts.get(cc, '')
        w.writerow([cc, tid, term, status])

print(f'Done! Written to {outfile}')
print(f'Total unique Read codes: {len(code_terms)}')
current = sum(1 for cc in code_terms if concepts.get(cc) == 'C')
redundant = sum(1 for cc in code_terms if concepts.get(cc) == 'R')
optional = sum(1 for cc in code_terms if concepts.get(cc) == 'O')
print(f'Current (C) codes: {current}')
print(f'Redundant (R) codes: {redundant}')
print(f'Optional (O) codes: {optional}')
