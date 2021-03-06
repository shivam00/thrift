::
:: Licensed under the Apache License, Version 2.0 (the "License");
:: you may not use this file except in compliance with the License.
:: You may obtain a copy of the License at
::
::     http://www.apache.org/licenses/LICENSE-2.0
::
:: Unless required by applicable law or agreed to in writing, software
:: distributed under the License is distributed on an "AS IS" BASIS,
:: WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
:: See the License for the specific language governing permissions and
:: limitations under the License.
::

@ECHO OFF
SETLOCAL EnableDelayedExpansion

CD build\appveyor              || EXIT /B
CALL cl_banner_test.bat        || EXIT /B
CALL cl_setenv.bat             || EXIT /B
CD "%BUILDDIR%"                || EXIT /B

:: randomly fails on mingw; see Jira THRIFT-4106
SET DISABLED_TESTS=concurrency_test

%BASH% -lc "cd %BUILDDIR_MSYS% && ctest.exe -C %CONFIGURATION% --timeout 300 -VV -E '(%DISABLED_TESTS%)'" || EXIT /B
