@echo off
set /p id=git url: 
git init

echo "# Initiating" >> README.md
@pause
git add README.md

echo "# Adding all files to List
@pause
git add -A

echo "# Commit Now
set /p commit=Commit: 
@pause
git commit -m "%commit%"

echo "# Switching to Master Branch
@pause
git branch -M master

echo "# Adding remote origin
@pause
git remote add origin %id%

echo "# Push to Origin=>Master
@pause
git push -u origin master

echo "# Completed
@pause