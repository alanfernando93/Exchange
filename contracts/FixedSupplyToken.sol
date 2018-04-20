pragma solidity ^0.4.21;

// ----------------------------------------------------------------------------------------------
// Sample fixed supply token contract
// Enjoy. (c) BokkyPooBah 2017. The MIT Licence.
// ----------------------------------------------------------------------------------------------


// ERC Token Standard #20 Interface
// https://github.com/ethereum/EIPs/issues/20
contract ERC20Interface {
    // Obtenga la cantidad total de fichas
    function totalSupply() view public returns (uint256);

    // Obtener el saldo de la cuenta de otra cuenta con la dirección _owner
    function balanceOf(address _owner) view public returns (uint256);

    // Enviar _value cantidad de tokens a la dirección _to
    function transfer(address _to, uint256 _value) public returns (bool success);

    // Enviar _valor cantidad de tokens desde la dirección _desde a la dirección _to
    function transferFrom(address _from, address _to, uint256 _value) public returns (bool success);

    // Permita que _spender se retire de su cuenta, varias veces, hasta el valor _value.
    // Si se llama de nuevo a esta función, sobrescribe la asignación actual con _value.
    // esta función es necesaria para algunas funcionalidades DEX
    function approve(address _spender, uint256 _value) public returns (bool success);

    // Devuelve la cantidad que _spender aún puede retirar de _owner
    function allowance(address _owner, address _spender) view public returns (uint256 remaining);

    // Disparo cuando se transfieren los tokens.
    event Transfer(address indexed _from, address indexed _to, uint256 _value);

    // Disparo cada vez que se aprueba (address _spender, uint256 _value).
    event Approval(address indexed _owner, address indexed _spender, uint256 _value);
}


contract FixedSupplyToken is ERC20Interface {
    string public constant symbol = "FIXED";
    string public constant name = "Example Fixed Supply Token";
    uint8 public constant decimals = 0;
    uint256 _totalSupply = 1000000;

    // Dueño de este contrato
    address public owner;

    // Saldos para cada cuenta
    mapping (address => uint256) balances;

    // El titular de la cuenta aprueba la transferencia de un importe a otra cuenta
    mapping (address => mapping (address => uint256)) allowed;

    // Las funciones con este modificador solo pueden ser ejecutadas por el propietario
    modifier onlyOwner() {
        require(msg.sender == owner);
        _;
    }

    // Constructor
    function FixedSupplyToken() public {
        owner = msg.sender;
        balances[owner] = _totalSupply;
    }

    function totalSupply() view public returns (uint256) {
        return _totalSupply;
    }

    // ¿Cuál es el saldo de una cuenta en particular?
    function balanceOf(address _owner) view public returns (uint256) {
        return balances[_owner];
    }

    // Transfiere el saldo de la cuenta del propietario a otra cuenta
    function transfer(address _to, uint256 _amount) public returns (bool success) {
        if (balances[msg.sender] >= _amount
        && _amount > 0
        && balances[_to] + _amount > balances[_to]) {
            balances[msg.sender] -= _amount;
            balances[_to] += _amount;
            emit Transfer(msg.sender, _to, _amount);
            return true;
        }
        else {
            return false;
        }
    }

    // Enviar _valor cantidad de tokens desde la dirección _from a la dirección _to
    // El método transferFrom se utiliza para un flujo de trabajo de retirada, lo que permite enviar contratos
    // tokens en su nombre, por ejemplo, para "depositar" en una dirección de contrato y / o para cargar
    // tarifas en monedas secundarias; el comando debería fallar a menos que la cuenta _from
    // deliberadamente autorizó al emisor del mensaje a través de algún mecanismo; nos proponemos
    // estas API estandarizadas para su aprobación:
    function transferFrom(
    address _from,
    address _to,
    uint256 _amount
    ) public returns (bool) {
        if (balances[_from] >= _amount
        && allowed[_from][msg.sender] >= _amount
        && _amount > 0
        && balances[_to] + _amount > balances[_to]) {
            balances[_from] -= _amount;
            allowed[_from][msg.sender] -= _amount;
            balances[_to] += _amount;
            emit Transfer(_from, _to, _amount);
            return true;
        }
        else {
            return false;
        }
    }


    // Permita que _spender se retire de su cuenta, varias veces, hasta el valor _value.
    // Si se llama de nuevo a esta función, sobrescribe la asignación actual con _value.
    function approve(address _spender, uint256 _amount) public returns (bool success) {
        allowed[msg.sender][_spender] = _amount;
        emit Approval(msg.sender, _spender, _amount);
        return true;
    }

    function allowance(address _owner, address _spender) view public returns (uint256 remaining) {
        return allowed[_owner][_spender];
    }

}
