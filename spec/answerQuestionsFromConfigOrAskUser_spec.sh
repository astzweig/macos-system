Describe 'answerQuestionsFromConfigOrAskUser'
  Include ./install.sh
  mod="testmod"

  It 'does nothing if module has no questions' 
    declare -A questions=()
    When call answerQuestionsFromConfigOrAskUser 
    The output should eq ''
    The variable 'questions' should eq ''
    The status should be success
  End

  It 'asks the user if the question is not in the config' 
    declare -A questions=([question-one]=$'What is your favorite color?\ninfo')
    Data 'blue'
    config() {}
    When call answerQuestionsFromConfigOrAskUser
    The output should eq "What is your favorite color? "
    The status should be success
  End

  It 'does not ask the user if the question is stored in the config' 
    declare -A questions=([question-one]=$'What is your favorite color?\ninfo')
    config() { [ "${1}" = read ] && echo red; }
    When call answerQuestionsFromConfigOrAskUser
    The output should eq ''
    The status should be success
  End

  It 'stores the answer in the answers array if asking user'
    declare -A answers
    declare -A questions=([question-one]=$'What is your favorite color?\ninfo')
    config() {}
    Data 'blue'
    When call answerQuestionsFromConfigOrAskUser
    The output should eq "What is your favorite color? "
    The variable "answers[${mod}_question-one]" should eq 'blue'
    The status should be success
  End

  It 'stores the answer in the answers array if retrieving from config'
    declare -A answers
    declare -A questions=([question-one]=$'What is your favorite color?\ninfo')
    config() { [ "${1}" = read ] && echo red; }
    When call answerQuestionsFromConfigOrAskUser
    The output should eq ''
    The variable "answers[${mod}_question-one]" should eq 'red'
    The status should be success
  End

  It 'stores the user answer to config'
    declare -A answers
    declare -A questions=([question-one]=$'What is your favorite color?\ninfo')
    writtenValue=""
    Data 'red'
    config() { [ "${1}" = read ] && return; [ "${1}" = write ] && writtenValue="${2}" }
    When call answerQuestionsFromConfigOrAskUser
    The output should eq "What is your favorite color? "
    The variable "answers[${mod}_question-one]" should eq 'red'
    Assert test "${writtenValue}" = 'red'
    The status should be success
  End
End
